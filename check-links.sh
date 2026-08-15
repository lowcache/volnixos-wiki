#!/usr/bin/env bash
# Internal link check over the BUILT site.
#
# Why this exists: `mkdocs build --strict` failed the build on a broken internal
# link. Hugo does not. It only errors on broken `ref`/`relref` shortcodes, and the
# MkDocs port deliberately kept plain markdown links to preserve URLs — so a
# typo'd [text](phone/nix-on-drod/) publishes a 404 with a green build. Once
# push-to-deploy is on, that reaches production unattended. This closes the gap.
#
# Checks resolvable internal paths only. External URLs are NOT fetched: a network
# check in CI is flaky and would fail builds for reasons that are not our bug.
# Fragments (#anchor) are stripped rather than verified.
#
# Runs against public/ after hugo, so it sees exactly what would be uploaded.

set -eu

root=${1:-public}
[ -d "$root" ] || { echo "check-links: no such directory: $root" >&2; exit 1; }

fail=0
checked=0

# Minified output emits unquoted attributes (href=/a/b/), so both forms matter.
while IFS= read -r line; do
  file=${line%%:*}
  url=${line#*:}

  # Strip fragment and query.
  url=${url%%#*}
  url=${url%%\?*}
  [ -n "$url" ] || continue

  # Internal absolute paths only. Skip protocol-relative (//host).
  case $url in
    //*) continue ;;
    /*)  ;;
    *)   continue ;;
  esac

  checked=$((checked + 1))

  # A directory URL resolves to its index.html; otherwise try the literal file,
  # then the pretty-URL and .html variants Hugo can emit.
  target="$root$url"
  if [ "${url%/}" != "$url" ]; then
    [ -f "${target}index.html" ] && continue
  else
    [ -e "$target" ] && continue
    [ -f "$target/index.html" ] && continue
    [ -f "$target.html" ] && continue
  fi

  echo "BROKEN: $url  (linked from ${file#"$root"/})" >&2
  fail=1
done <<EOF
$(grep -rohE 'href="[^"]*"|href=[^ >]+' "$root" --include='*.html' \
    | sed -e 's/^href=//' -e 's/^"//' -e 's/"$//' \
    | sort -u \
    | while read -r u; do
        # Re-attach a source file for the report; first match is enough.
        src=$(grep -rlE "href=\"?${u//\//\\/}\"?" "$root" --include='*.html' 2>/dev/null | head -1)
        printf '%s:%s\n' "${src:-$root}" "$u"
      done)
EOF

if [ "$fail" -ne 0 ]; then
  echo "check-links: broken internal links found — not publishing" >&2
  exit 1
fi

echo "check-links: $checked internal links OK"
