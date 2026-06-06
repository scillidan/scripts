#!/bin/bash
# Delete local & remote tag, then recreate and push it
# Authors: perplexity.ai🧙‍♂️, scillidan🤡

tag_name="$1"

if [ -z "$tag_name" ]; then
  echo "Usage: $(basename "$0") <tag>"
  exit 1
fi

# Delete local tag if exists
if git tag | grep -q "^${tag_name}$"; then
  echo "Deleting local tag: $tag_name"
  git tag -d "$tag_name"
else
  echo "Local tag '$tag_name' not found, skipping deletion."
fi

# Delete remote tag
echo "Deleting remote tag: $tag_name (if exists)"
git push origin --delete "$tag_name" 2>/dev/null || true

# Recreate and push tag
echo "Creating and pushing new tag: $tag_name"
git tag "$tag_name"
git push origin "$tag_name"

echo "✅ Tag refreshed: $tag_name"
