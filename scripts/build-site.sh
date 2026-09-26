#!/usr/bin/env bash
# Local preview of the site built by .github/workflows/site.yaml: the
# yihui/actions litedown-site templates plus docs/ rendered under docs/.
# Needs rho and a current litedown (https://yihui.r-universe.dev) installed.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tpl=$(mktemp -d)
trap 'rm -rf "$tpl"' EXIT
git clone --quiet --depth 1 https://github.com/yihui/actions "$tpl"
rm -rf "$root/_site" && mkdir -p "$root/_site/docs"
cd "$root/_site"
cp "$root"/docs/*.md docs/
touch -d 2000-01-01 docs/index.html
cp "$tpl"/litedown-site/{_litedown.yml,_footer.Rmd,index.Rmd,manual.Rmd,news.Rmd} .
Rscript -e "litedown::fuse('_footer.Rmd', '.md')"
Rscript -e "litedown::fuse_site()"
rm -f ./*.Rmd ./*.yml ./_*
touch .nojekyll
echo "Site written to $root/_site"
