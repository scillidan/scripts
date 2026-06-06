#!/bin/bash
# Auto commit with current datetime as message

timestamp="$(date +"%Y-%m-%dT%H:%M:%S")"

git add .
git commit -m "$timestamp"
git push
