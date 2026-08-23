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

# Post-deploy smoke test. This used to curl $(SITE)/ and nothing else, which
# passes even when every subpage 404s — the homepage is the one URL a broken
# upload is most likely to still serve, so it is the worst thing to check alone.
# Walk the sitemap, the way volnixos-blog and hotelevangelism already do.
#
# The pagefind assertion is wiki-specific and load-bearing. E25DX renders the
# search box but builds no index; build.sh runs `pagefind --site public` after
# hugo. Skip that step and the box still renders, every query just returns
# nothing — so a 200 on any page tells you nothing about search. Read the live
# index and require it to report pages.
verify:
	@echo "++ Verifying $(SITE)"; \
	test -f public/sitemap.xml || { echo "++ no public/sitemap.xml - run 'make build' first" >&2; exit 2; }; \
	rc=0; \
	urls=$$(grep -o '<loc>[^<]*</loc>' public/sitemap.xml | sed 's/<[^>]*>//g'); \
	n=$$(printf '%s\n' "$$urls" | grep -c .); \
	[ "$$n" -gt 0 ] || { echo "++ sitemap.xml has no <loc> entries - refusing to pass" >&2; exit 2; }; \
	for u in $$urls $(SITE)/robots.txt $(SITE)/sitemap.xml $(SITE)/index.xml; do \
	  code=$$(curl -sS -o /dev/null -w '%{http_code}' -m 20 "$$u"); \
	  [ "$$code" = "200" ] || { printf "  %-6s %s\n" "$$code" "$$u"; rc=1; }; \
	done; \
	pf=$$(curl -sS -m 20 "$(SITE)/pagefind/pagefind-entry.json" | grep -o '"page_count":[0-9]*' | head -1 | cut -d: -f2); \
	case "$$pf" in \
	  ''|0) printf "  %-6s %s\n" "EMPTY" "$(SITE)/pagefind/pagefind-entry.json (search index missing or indexed 0 pages)"; rc=1 ;; \
	  *)    echo "  pagefind index: $$pf pages" ;; \
	esac; \
	[ $$rc -eq 0 ] && echo "++ OK - $$n sitemap URLs + robots/sitemap/feed + pagefind all good" \
	               || echo "++ FAILED - see non-200 responses above"; \
	exit $$rc

# The theme is pinned in go.mod by commit. This is the deliberate way to move it.
mod-update:
	$(HUGO) mod get -u github.com/dumindu/E25DX
	$(HUGO) mod tidy

clean:
	rm -rf public resources .hugo_build.lock
