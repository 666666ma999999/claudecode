#!/bin/zsh
echo "=== parent dir listing (autopost エントリの種類が分かる) ==="
ls -la@O ~/Desktop/biz/ | grep -i autopost
echo ""
echo "=== stat autopost ==="
stat ~/Desktop/biz/autopost
echo ""
echo "=== file flags / ACL ==="
ls -leO@ -d ~/Desktop/biz/autopost
echo ""
echo "=== extended attributes ==="
xattr -l ~/Desktop/biz/autopost
echo ""
echo "=== symlink check ==="
readlink ~/Desktop/biz/autopost && echo "↑ symlink" || echo "not a symlink"
echo ""
echo "=== brctl status (iCloud sync state) ==="
brctl status ~/Desktop/biz/autopost 2>&1 | head -20
echo ""
echo "=== mdls (Spotlight metadata, cloud info) ==="
mdls -name kMDItemIsCloudItem -name kMDItemFSName ~/Desktop/biz/autopost 2>&1
