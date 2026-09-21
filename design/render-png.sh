#!/bin/sh
# Renders every artboard in design/project to design/png with headless Chrome.
cd "$(dirname "$0")/.." || exit 1
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for f in design/project/*.dc.html; do
  b=$(basename "$f" .dc.html)
  case $b in *Menu) sz=480,620;; *) sz=1280,820;; esac
  "$CH" --headless=new --disable-gpu --hide-scrollbars --window-size=$sz \
    --virtual-time-budget=4000 --screenshot="design/png/$b.png" "file://$PWD/$f" 2>/dev/null
done
ls design/png
