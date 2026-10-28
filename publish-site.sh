#!/usr/bin/env bash
# Build the public Pages site from this private repo and force-push it to the
# gh-pages branch as a single commit, so IPAs never pile up in history.
#
# The site is only <hash>/ (from site.env): source.json, images, the page and
# every IPA source.json links to. The root has nothing, and Pages has no
# directory listing, so the source is reachable only by its full URL.
#
# IPAs live in ipas/ (not in git); one missing there is fetched from the
# private GitHub release that holds it.
set -euo pipefail
cd "$(dirname "$0")"
. ./site.env

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
dir="$out/${SITE_URL##*/}"
mkdir -p "$dir" ipas
touch "$out/.nojekyll"
cp source.json index.html store-icon.png store-header.png icon.png vispr-icon.png "$dir/"

for file in $(python3 -c "
import json, sys
s = json.load(open('source.json'))
for a in s['apps']:
    for v in a['versions']:
        assert v['downloadURL'].startswith(sys.argv[1] + '/'), v['downloadURL']
        print(v['downloadURL'].rsplit('/', 1)[1])
" "$SITE_URL"); do
  if [ ! -f "ipas/$file" ]; then
    tag=$(gh release list --limit 200 --json tagName -q '.[].tagName' |
      while read -r t; do gh release view "$t" --json assets -q '.assets[].name' | grep -qx "$file" && echo "$t" && break; done)
    [ -n "$tag" ] || { echo "no release has $file" >&2; exit 1; }
    gh release download "$tag" -p "$file" -D ipas
  fi
  cp "ipas/$file" "$dir/"
done

git -C "$out" init -q -b gh-pages
git -C "$out" add -A
git -C "$out" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" commit -qm "site $(date -u +%Y-%m-%dT%H:%MZ)"
git -C "$out" push -q -f "$(git remote get-url origin)" gh-pages
echo "published $SITE_URL/source.json"
