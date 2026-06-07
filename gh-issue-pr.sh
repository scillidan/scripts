#!/bin/bash

gh issue list --search "$1" && gh pr list --search "$1" --state open --limit 200