#!/bin/bash
# Create hard links to GGUF files from Ollama models directory.
# Authors: GLM-5🧙‍♂️, scillidan🤡
#
# Usage:
#   bash link-ollama-ggufs.sh --output GGUF_DIR [--ollama-models OLLAMA_PATH] [-y|--yes]
#
# Options:
#   --ollama-models   Ollama data directory (default: $OLLAMA_MODELS or ~/.ollama/models)
#   --output        Output directory for GGUF hard links (required)
#   -y, --yes       Auto-confirm all updates (non-interactive)
#   -h, --help      Show this help message
#
# Examples:
#   bash link-ollama-ggufs.sh --output ~/gguf-models
#   bash link-ollama-ggufs.sh --ollama-models ~/.ollama/models --output ~/gguf-models
#   bash link-ollama-ggufs.sh --output %USERPROFILE%/gguf-models  # Windows

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

show_help() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}

expand_path() {
  local path="$1"

  # Handle Windows-style paths that Git Bash may pass (C:\Users\... or C:/Users/...)
  if [[ "$path" =~ ^[A-Za-z]:[\\/] ]]; then
    path="${path//\\//}"
    local drive="${path:0:1}"
    local restpath="${path:2}"
    path="/${drive,,}${restpath}"
  fi

  # Expand %VAR% style (Windows) to actual value
  while [[ "$path" == *%*%* ]]; do
    local before="${path%%\%*}"
    local rest="${path#*\%}"
    local varname="${rest%%\%*}"
    local after="${rest#*\%}"
    local varvalue=$(printenv "$varname" 2>/dev/null || echo "")
    if [ -n "$varvalue" ]; then
      varvalue="${varvalue//\\//}"
      local drive="${varvalue:0:1}"
      local restpath="${varvalue:2}"
      varvalue="/${drive,,}${restpath}"
    fi
    path="${before}${varvalue}${after}"
  done

  # Expand $VAR and ~/ style paths
  eval echo "$path"
}

get_inode() {
  stat -c %i "$1" 2>/dev/null || stat -f %i "$1" 2>/dev/null || ls -i "$1" 2>/dev/null | awk '{print $1}'
}

same_file() {
  local file1="$1"
  local file2="$2"
  [ "$(get_inode "$file1")" = "$(get_inode "$file2")" ]
}

OLLAMA_PATH=""
OUTPUT_DIR=""
AUTO_YES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ollama-models)
      OLLAMA_PATH="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -y|--yes)
      AUTO_YES=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      echo "Use -h or --help for usage information."
      exit 1
      ;;
  esac
done

# Validate required --output option
if [ -z "$OUTPUT_DIR" ]; then
  echo "Error: --output is required." >&2
  echo "Use -h or --help for usage information."
  exit 1
fi

# Determine Ollama models directory
if [ -z "$OLLAMA_PATH" ]; then
  OLLAMA_PATH="${OLLAMA_MODELS:-$HOME/.ollama/models}"
fi

# Expand paths (handle environment variables)
OLLAMA_PATH=$(expand_path "$OLLAMA_PATH")
OUTPUT_DIR=$(expand_path "$OUTPUT_DIR")

# Convert to absolute paths
OLLAMA_PATH=$(cd "$OLLAMA_PATH" 2>/dev/null && pwd) || {
  echo "Error: Ollama directory does not exist: $OLLAMA_PATH" >&2
  exit 1
}

MANIFESTS="$OLLAMA_PATH/manifests/registry.ollama.ai"

if [ ! -d "$MANIFESTS" ]; then
  echo "Error: Manifests directory not found: $MANIFESTS" >&2
  echo "Please verify your Ollama models directory." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Linking GGUF files from Ollama ==="
echo
echo "Note:"
echo "  Hard links require both source and target on the same filesystem."
echo "  If hard link fails (cross-filesystem), script falls back to copying."
echo ""
echo "Ollama Models: $OLLAMA_PATH"
echo "Output: $OUTPUT_DIR"
echo ""

UPDATED_COUNT=0
SKIPPED_COUNT=0
ORPHANED_COUNT=0

TMPFILE=$(mktemp)
trap "rm -f '$TMPFILE'" EXIT

find "$MANIFESTS" -type f | while read -r mf; do
  # Derive model:tag name from path for output filename
  # manifests/.../library/gemma3/12b  → gemma3:12b
  rel="${mf#$MANIFESTS/}"
  tagname="${rel%/}"
  # Replace / with : (last / becomes :)
  nice_name=$(echo "$tagname" | sed 's|/|:|; s|/|:|')

  # Extract model layer digest from JSON
  digest=$(jq -r '.layers[] | select(.mediaType=="application/vnd.ollama.image.model") | .digest' "$mf" 2>/dev/null)

  if [ -z "$digest" ] || [ "$digest" = "null" ]; then
    echo "  SKIP $nice_name  (no model layer found)"
    echo ""
    continue
  fi

  # sha256:abc... → sha256-abc...
  blob_basename="${digest/:/-}"
  blob_path="$OLLAMA_PATH/blobs/$blob_basename"

  out_name=$(echo "$nice_name" | tr '/:' '--').gguf
  out_path="$OUTPUT_DIR/$out_name"

  echo "$out_name" >> "$TMPFILE"

  # Case 1: Target doesn't exist
  if [ ! -e "$out_path" ]; then
    if [ ! -f "$blob_path" ]; then
      echo "  ERROR $nice_name"
      echo "    Source blob not found: $blob_path"
      echo "    Model may have been removed from Ollama."
      echo ""
      continue
    fi

    sz=$(du -sh "$blob_path" | cut -f1)
    echo "  NEW $nice_name  ($sz)"
    echo "    blob: $blob_basename"

    if ln "$blob_path" "$out_path" 2>/dev/null; then
      echo "    -> $out_path (hard link)"
    else
      cp "$blob_path" "$out_path"
      echo "    -> $out_path (copied - different filesystem?)"
    fi
    echo ""
    continue
  fi

  # Target exists - check relationship with blob
  if [ ! -f "$blob_path" ]; then
    # Case 2: Target exists but blob is gone (orphaned manifest)
    echo -e "  ${RED}ORPHANED${NC} $nice_name"
    echo "    Target: $out_path"
    echo "    Source blob no longer exists: $blob_path"
    echo "    The target file may have been a hard link to a deleted Ollama model."
    echo "    Warning: Data may be lost if you remove Ollama models."
    echo ""
    continue
  fi

  # Check if target is already a hard link to the correct blob
  if same_file "$blob_path" "$out_path"; then
    # Case 3: Already correct hard link
    sz=$(du -sh "$blob_path" | cut -f1)
    echo -e "  ${GREEN}OK${NC} $nice_name  ($sz) - already linked"
    continue
  fi

  # Target exists but is different file
  out_sz=$(du -sh "$out_path" | cut -f1)
  blob_sz=$(du -sh "$blob_path" | cut -f1)

  # Check if target is a hard link to something else
  out_links=$(stat -c %h "$out_path" 2>/dev/null || stat -f %l "$out_path" 2>/dev/null || echo "1")

  if [ "$out_links" -gt 1 ]; then
    # Case 4: Hard link to different blob (model updated)
    echo "  UPDATE $nice_name"
    echo "    Current: $out_path ($out_sz) - linked to old version"
    echo "    New blob: $blob_basename ($blob_sz)"
    action="update link"
  else
    # Case 5: Independent file (not a hard link)
    echo "  CONFLICT $nice_name"
    echo "    Existing: $out_path ($out_sz) - standalone file"
    echo "    New blob: $blob_basename ($blob_sz)"
    action="replace with link"
  fi

  if $AUTO_YES; then
    response="y"
  else
    echo -n "    $action? [y/N] "
    read -r response < /dev/tty
  fi

  if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -f "$out_path"
    if ln "$blob_path" "$out_path" 2>/dev/null; then
      echo "    -> Updated: $out_path (hard link)"
    else
      cp "$blob_path" "$out_path"
      echo "    -> Updated: $out_path (copied - different filesystem?)"
    fi
  else
    echo "    -> Skipped (keeping existing file)"
  fi
  echo ""
done

ORPHAN_FILES=()
for gguf in "$OUTPUT_DIR"/*.gguf; do
  [ -f "$gguf" ] || continue
  basename=$(basename "$gguf")
  if ! grep -Fxq "$basename" "$TMPFILE" 2>/dev/null; then
    ORPHAN_FILES+=("$gguf")
  fi
done

if [ ${#ORPHAN_FILES[@]} -gt 0 ]; then
  echo ""
  echo -e "${RED}=== Orphaned files (no longer in Ollama) ===${NC}"
  echo ""
  for gguf in "${ORPHAN_FILES[@]}"; do
    sz=$(du -sh "$gguf" | cut -f1)
    echo -e "  ${RED}ORPHAN${NC} $(basename "$gguf")  ($sz)"
    echo "    $gguf"
  done
  echo ""
  if $AUTO_YES; then
    response="n"
  else
    echo -n "Remove these orphaned files? [y/N] "
    read -r response < /dev/tty
  fi
  if [[ "$response" =~ ^[Yy]$ ]]; then
    for gguf in "${ORPHAN_FILES[@]}"; do
      rm -f "$gguf"
      echo "    Removed: $(basename "$gguf")"
    done
  else
    echo "    Kept orphaned files."
  fi
fi

echo ""
echo "=== Done. Files in $OUTPUT_DIR ==="
echo ""
ls -lh "$OUTPUT_DIR/"
