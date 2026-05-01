#!/bin/zsh
echo "=== ulimit (raise then check) ==="
ulimit -n 65536
echo "ulimit -n => $(ulimit -n)"
echo ""
echo "=== folder ==="
cd ~/Desktop/biz/autopost || { echo "FOLDER NOT FOUND"; exit 1; }
pwd
echo ""
echo "=== ls -la ==="
ls -la
echo ""
echo "=== file count ==="
find . -type f 2>/dev/null | wc -l
echo ""
echo "=== claude version ==="
which claude
claude --version
echo ""
echo "=== claude --debug (first 40 lines) ==="
claude --debug 2>&1 | head -40
