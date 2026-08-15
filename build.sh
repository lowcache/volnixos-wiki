#!/usr/bin/env bash
# The one build. Mirrors the blog's build.sh so both sites mean the same thing by
# "build this site", and is called from two places:
#
#   1. Workers Builds — dashboard Build command (Settings > Build), set to
#      `./build.sh`. Workers Builds does NOT read a [build] block in
#      wrangler.toml, so without this script the CI steps live only in a
#      dashboard text field, unreviewed and free to drift from the repo.
#   2. `make build` — directly, with the flake-pinned hugo on PATH.
#
# Expects `hugo`, `go` and `pagefind` on PATH. Locally the Makefile supplies the
# flake-pinned ones; on Cloudflare hugo comes from the build image, pinned by the
# HUGO_VERSION build variable. The guard below is what makes those two agree.
#
# `go` is required because the E25DX theme is a Hugo Module (no git submodules),
# and module resolution shells out to the go binary.

set -eu

want=$(tr -d '[:space:]' < .hugo-version)
got=$(hugo version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v)
if [ "$want" != "$got" ]; then
  echo "Hugo pin mismatch: .hugo-version=$want but hugo on PATH is $got" >&2
  echo "Set the HUGO_VERSION build variable to $want, or update .hugo-version." >&2
  exit 1
fi

hugo --minify --cleanDestinationDir

# Search. E25DX renders the search UI but does not build an index — pagefind
# crawls the finished HTML and writes public/pagefind/. Skipping this step is
# silent: the box renders and every query returns nothing.
#
# Two sources on purpose. Locally the flake supplies pagefind (pinned, offline).
# The Cloudflare build image does NOT ship it, so CI falls back to npx. Without
# the fallback every Workers build fails at this line.
if command -v pagefind >/dev/null 2>&1; then
  pagefind --site public
elif command -v npx >/dev/null 2>&1; then
  npx -y pagefind@1 --site public
else
  echo "no pagefind and no npx — search index cannot be built" >&2
  exit 1
fi

# The failure this whole file exists to prevent: publishing an empty directory.
# Uploading nothing is not an error to wrangler, so it has to be one here.
[ -f public/index.html ]   || { echo "build produced no public/index.html" >&2; exit 1; }
[ -f public/sitemap.xml ]  || { echo "build produced no public/sitemap.xml" >&2; exit 1; }
[ -d public/pagefind ]     || { echo "build produced no search index" >&2; exit 1; }

echo "built $(find public -name '*.html' | wc -l) html files"
