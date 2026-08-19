# Volatile NixOS wiki — Hugo + E25DX, deployed to Cloudflare Workers.
# Hugo runs from this repo's flake (no global install); mirrors the blog's flow.
#
# The Worker name and the asset directory live in ./wrangler.toml, not here —
# `wrangler deploy` reads them. SITE is only used for the post-deploy smoke test.
SITE ?= https://wiki.infernalcode.com
# '#' starts a Make comment, so the flake ref is assembled with an escaped hash.
HASH := \#
# Resolved through ./flake.nix, not `nixpkgs#hugo`, which follows the local
# registry and drifts between Hugo releases — and a drift changes rendered
# output. `go` comes along because the theme is a Hugo Module (no submodules)
# and module resolution needs it; `pagefind` builds the search index.
HUGO     = nix shell .$(HASH)hugo .$(HASH)go --command hugo
BUILD    = nix shell .$(HASH)hugo .$(HASH)go .$(HASH)pagefind --command ./build.sh
WRANGLER = nix shell .$(HASH)wrangler --command wrangler
# Cloudflare deploy token from sops. wrangler keeps its OAuth credentials under
# ~/.config/.wrangler, which impermanence discards on every boot (that path is
# not in home/persist.nix), so `wrangler login` survives only until the next
# reboot and a local deploy then fails with "non-interactive environment".
# wrangler reads CLOUDFLARE_API_TOKEN from the env and has no --token flag, so
# the recipe cats this into that one command rather than exporting it.
CF_TOKEN_FILE ?= /run/secrets/cloudflare_api_token

.PHONY: help serve build deploy verify clean mod-update

help:
	@echo "make serve       Live preview incl. drafts (http://localhost:1313)"
	@echo "make build       Production build to ./public (runs ./build.sh)"
	@echo "make deploy      Build, upload ./public to Cloudflare Workers, then verify"
	@echo "make verify      Smoke-test the live site ($(SITE))"
	@echo "make mod-update  Update the E25DX theme module"
	@echo "make clean       Remove build output"

serve:
	$(HUGO) server -D

build:
	$(BUILD)

# The normal deploy is `git push` -> Workers Builds runs ./build.sh. This local
# path is the rescue route: same script, flake-pinned toolchain, uploaded
# directly. Use it when a build is stuck or a known-good tree must ship now.
deploy: build
	@test -r "$(CF_TOKEN_FILE)" || test -n "$$CLOUDFLARE_API_TOKEN" \
	  || { echo "no Cloudflare token: $(CF_TOKEN_FILE) unreadable and CLOUDFLARE_API_TOKEN unset"; exit 1; }
	@CLOUDFLARE_API_TOKEN="$$(test -r '$(CF_TOKEN_FILE)' && cat '$(CF_TOKEN_FILE)' || echo "$$CLOUDFLARE_API_TOKEN")" \
	  $(WRANGLER) deploy
	@$(MAKE) --no-print-directory verify

verify:
	@code=$$(curl -s -o /dev/null -w '%{http_code}' $(SITE)/); \
	 echo "$(SITE)/ -> $$code"; \
	 [ "$$code" = "200" ] || { echo "site did not return 200" >&2; exit 1; }

# The theme is pinned in go.mod by commit. This is the deliberate way to move it.
mod-update:
	$(HUGO) mod get -u github.com/dumindu/E25DX
	$(HUGO) mod tidy

clean:
	rm -rf public resources .hugo_build.lock
