# Volatile NixOS wiki — build and deploy.
#
# These targets used to live in ~/.nix-config/Makefile as docs-serve/docs-build/
# docs-deploy, back when the pages were a symlink into this directory. They moved
# here with the repo. The old MKDOCS variable evaluated `builtins.getFlake` on the
# config root, which copied the whole repo into the store and failed on the
# AF_UNIX socket sitting in it:
#   error: file '/home/lowcache/.nix-config/tailscale.sock' has an unsupported type
# Building from this repo sidesteps that entirely.

VENV        ?= .venv
PY          ?= python3
MKDOCS      := $(VENV)/bin/mkdocs
DOCS_REMOTE ?= pgs.sh
DOCS_PROJECT?= wiki

.PHONY: help venv serve build deploy deploy-cf clean

## :help: ...............: Show this help
help:
	@sed -n 's/^## //p' $(MAKEFILE_LIST)

## :venv: ...............: Install the pinned mkdocs toolchain into .venv
venv: $(MKDOCS)
$(MKDOCS):
	$(PY) -m venv $(VENV)
	$(VENV)/bin/pip install --quiet --upgrade pip
	$(VENV)/bin/pip install --quiet -r docs/requirements.txt

## :serve: ..............: Live-preview at 127.0.0.1:8000
serve: venv
	$(MKDOCS) serve

## :build: ..............: Build the static site strictly to ./site
build: venv
	$(MKDOCS) build --strict

## :deploy-cf: ..........: Build, then publish to Cloudflare (wrangler.toml)
deploy-cf: build
	npx wrangler deploy

## :deploy: .............: Build, then rsync ./site to the pgs.sh host
deploy: build
	rsync --delete -rv ./site/ $(DOCS_REMOTE):/$(DOCS_PROJECT)

## :clean: ..............: Remove the built site
clean:
	rm -rf site
