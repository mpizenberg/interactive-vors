#!/usr/bin/env bash

# Requires to have configured worktree with
# git worktree add gh-pages-static/ gh-pages

set -e
cd gh-pages-static
git reset --hard 4673c15
cp -rH ../static/* .
git add . --force
git commit -m "Publish"
git push --force
