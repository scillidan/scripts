#!/bin/bash

gitinit() {
  local user_repo="$1"
  local add_files="${2:-.}"
  local commit_msg="${3:-Initial commit}"

  if [ -z "$user_repo" ]; then
    echo "Usage: gitinit <user>/<repo>(.git) [files] [commit-message]"
    return 1
  fi

  echo "Initializing git repository..."
  git init
  echo "Adding remote origin: https://github.com/$user_repo"
  git remote add origin "https://github.com/$user_repo"
  echo "Creating and switching to the main branch..."
  git branch -M main
  echo "Adding files: $add_files"
  git add $add_files
  echo "Committing with message: $commit_msg"
  git commit -m "$commit_msg"
  echo "Pushing to origin..."
  git push -u origin main
}

# Call the function with arguments
gitinit "$@"