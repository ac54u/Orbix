#!/bin/bash
# 将本地提交推送到指定远程仓库 https://github.com/ac54u/orbix.git
set -e

# Use GITHUB_TOKEN for authentication if set
if [ -n "$GITHUB_TOKEN" ]; then
    REMOTE_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/ac54u/orbix.git"
else
    REMOTE_URL="https://github.com/ac54u/orbix.git"
fi

# Ensure origin remote exists and points to correct URL
if ! git remote get-url origin &>/dev/null; then
    git remote add origin "$REMOTE_URL"
else
    git remote set-url origin "$REMOTE_URL"
fi

# Remote default branch is master, local branch is main
git push origin main:master
git push --tags
