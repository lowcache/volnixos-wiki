#!/usr/bin/env bash
# Internal link check over the BUILT site.
#
# Why this exists: `mkdocs build --strict` failed the build on a broken internal
# link. Hugo does not. It only errors on broken `ref`/`relref` shortcodes, and the
# MkDocs port deliberately kept plain markdown links to preserve URLs — so a
# typo'd [text](phone/nix-on-drod/) publishes a 404 with a green build. Once
# push-to-deploy is on, that reaches production unattended. This closes the gap.
#
# Checks internal paths AND their #fragments; both kinds have shipped broken
# (stale em-dash anchors 2026-08-20, 72 relative links 2026-10-12). A relative
# href in the output is itself an error: render-link.html makes every markdown
# link absolute, so one surviving means raw HTML bypassed it, and it resolves
# against the page URL, not the source file.
#
# External URLs are NOT fetched: a network check in CI is flaky and would fail
# builds for reasons that are not our bug.
#
# Runs against public/ after hugo, so it sees exactly what would be uploaded.

set -eu

root=${1:-public}
[ -d "$root" ] || { echo "check-links: no such directory: $root" >&2; exit 1; }

fail=0
checked=0
frags=0

broken() { echo "BROKEN: $1  (linked from ${2#"$root"/}) $3" >&2; fail=1; }

while IFS= read -r file; do
  # Minified output emits unquoted attributes (href=/a/b/), so both forms matter.
  while IFS= read -r url; do
    path=${url%%#*}
    path=${path%%\?*}
    frag=
    case $url in *#*) frag=${url#*#} ;; esac

    case $path in
      //*|*:*) continue ;;              # protocol-relative or has a scheme
      "")
        [ -n "$frag" ] || continue
        target=$file ;;                 # same-page #anchor
      /*)
        checked=$((checked + 1))
        # A directory URL resolves to its index.html; otherwise try the literal
        # file, then the pretty-URL and .html variants Hugo can emit.
        t="$root$path"
        if [ "${path%/}" != "$path" ]; then
          target="${t}index.html"
        elif [ -f "$t" ]; then
          target=$t
        elif [ -f "$t/index.html" ]; then
          target="$t/index.html"
        else
          target="$t.html"
        fi
        [ -f "$target" ] || { broken "$url" "$file" ""; continue; } ;;
      *)
        broken "$url" "$file" "[relative href: bypassed render-link.html]"
        continue ;;
    esac

    [ -n "$frag" ] || continue
    frags=$((frags + 1))
    grep -qF -e "id=\"$frag\"" -e "id=$frag " -e "id=$frag>" "$target" \
      || broken "$url" "$file" "[no id=$frag in ${target#"$root"/}]"
  done < <(grep -ohE 'href="[^"]*"|href=[^ >]+' "$file" \
             | sed -e 's/^href=//' -e 's/^"//' -e 's/"$//' | sort -u)
done < <(find "$root" -name '*.html' -not -path "$root/pagefind/*")

if [ "$fail" -ne 0 ]; then
  echo "check-links: broken internal links found — not publishing" >&2
  exit 1
fi

echo "check-links: $checked internal links, $frags fragments OK"
