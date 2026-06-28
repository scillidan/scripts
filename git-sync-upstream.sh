#!/usr/bin/env bash
# Sync fork's master branch with upstream/master
# Authors: DeepSeek🧙‍♂️, scillidan🤡
# Usage: ./git_sync-upstream.sh [branch]

set -e

BRANCH="${1:-$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')}"

git checkout "$BRANCH"
git fetch upstream "$BRANCH" --no-tags
git merge "upstream/$BRANCH" --no-edit
git push origin "$BRANCH"