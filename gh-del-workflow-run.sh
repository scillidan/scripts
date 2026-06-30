#!/usr/bin/env bash
# Usage: bash script.sh <owner/repo>

set -uo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <owner/repo>"
  exit 1
fi

REPO="$1"

RAW_JSON=$(gh workflow list --repo "$REPO" --json name,state,id | tr -d '\r')
mapfile -t WORKFLOWS < <(echo "$RAW_JSON" | jq -c '.[]')

if [ ${#WORKFLOWS[@]} -eq 0 ]; then
  echo "No workflows found."
  exit 0
fi

echo "Workflows in $REPO:"
for i in "${!WORKFLOWS[@]}"; do
  NAME=$(echo "${WORKFLOWS[$i]}" | jq -r '.name')
  STATE=$(echo "${WORKFLOWS[$i]}" | jq -r '.state')
  ID=$(echo "${WORKFLOWS[$i]}" | jq -r '.id')
  printf "  %d) [%s] %s (ID: %s)\n" "$((i+1))" "$STATE" "$NAME" "$ID"
done

echo ""
read -rp "Select workflow(s) by number or ID (e.g. 2 or 1,3): " INPUT

if [ -z "$INPUT" ]; then
  echo "No input. Aborted."
  exit 1
fi

SELECTED_IDXS=()
IFS=',' read -ra PARTS <<< "$INPUT"
for part in "${PARTS[@]}"; do
  part=$(echo "$part" | tr -d ' \r')
  if [[ "$part" =~ ^[0-9]+$ ]]; then
    IDX=$((part-1))
    if [ "$IDX" -ge 0 ] && [ "$IDX" -lt "${#WORKFLOWS[@]}" ]; then
      SELECTED_IDXS+=("$IDX")
    else
      for i in "${!WORKFLOWS[@]}"; do
        WF_ID=$(echo "${WORKFLOWS[$i]}" | jq -r '.id')
        if [ "$WF_ID" = "$part" ]; then
          SELECTED_IDXS+=("$i")
          break
        fi
      done
    fi
  fi
done

SELECTED_IDXS=($(echo "${SELECTED_IDXS[@]}" | tr ' ' '\n' | sort -n | uniq))

if [ ${#SELECTED_IDXS[@]} -eq 0 ]; then
  echo "Nothing selected. Aborted."
  exit 1
fi

declare -A RUNS_TO_DELETE=()
declare -A WF_NAMES=()
declare -A WF_ALL_RUNS=()

for idx in "${SELECTED_IDXS[@]}"; do
  WF_NAMES[$idx]=$(echo "${WORKFLOWS[$idx]}" | jq -r '.name')
  WF_ID=$(echo "${WORKFLOWS[$idx]}" | jq -r '.id')

  echo ""
  echo "Workflow: ${WF_NAMES[$idx]} (ID: $WF_ID)"

  RUN_JSON=$(gh run list --repo "$REPO" --workflow "${WF_NAMES[$idx]}" --limit 100 \
    --json status,databaseId,displayTitle,createdAt | tr -d '\r')
  mapfile -t RUNS < <(echo "$RUN_JSON" | jq -c '.[]')

  if [ ${#RUNS[@]} -eq 0 ] || [ "${RUNS[0]}" = "null" ]; then
    echo "  (no runs)"
    continue
  fi

  echo "  Runs:"
  for i in "${!RUNS[@]}"; do
    STATUS=$(echo "${RUNS[$i]}" | jq -r '.status')
    RID=$(echo "${RUNS[$i]}" | jq -r '.databaseId')
    TITLE=$(echo "${RUNS[$i]}" | jq -r '.displayTitle')
    DATE=$(echo "${RUNS[$i]}" | jq -r '.createdAt')
    printf "    %d) %s #%s %s (%s)\n" "$((i+1))" "$STATUS" "$RID" "$TITLE" "$DATE"
  done

  echo ""
  echo "  Select runs to delete:"
  echo "    All | number | range (1-3) | list (1,3,5)"
  read -rp "  Selection: " RUN_INPUT

  if [ -z "$RUN_INPUT" ]; then
    echo "  (skipped)"
    continue
  fi

  RUN_INPUT_LOWER=$(echo "$RUN_INPUT" | tr '[:upper:]' '[:lower:]')
  SELECTED_RUN_IDXS=()

  if [ "$RUN_INPUT_LOWER" = "all" ]; then
    for i in "${!RUNS[@]}"; do
      SELECTED_RUN_IDXS+=("$i")
    done
    WF_ALL_RUNS[$idx]=1
  else
    IFS=',' read -ra RPARTS <<< "$RUN_INPUT"
    for rpart in "${RPARTS[@]}"; do
      rpart=$(echo "$rpart" | tr -d ' \r')
      if [[ "$rpart" =~ ^[0-9]+-[0-9]+$ ]]; then
        RSTART=${rpart%-*}
        REND=${rpart#*-}
        for ((r=RSTART; r<=REND; r++)); do
          RIDX=$((r-1))
          if [ "$RIDX" -ge 0 ] && [ "$RIDX" -lt "${#RUNS[@]}" ]; then
            SELECTED_RUN_IDXS+=("$RIDX")
          fi
        done
      elif [[ "$rpart" =~ ^[0-9]+$ ]]; then
        RIDX=$((rpart-1))
        if [ "$RIDX" -ge 0 ] && [ "$RIDX" -lt "${#RUNS[@]}" ]; then
          SELECTED_RUN_IDXS+=("$RIDX")
        fi
      fi
    done
    WF_ALL_RUNS[$idx]=0
  fi

  SELECTED_RUN_IDXS=($(echo "${SELECTED_RUN_IDXS[@]}" | tr ' ' '\n' | sort -n | uniq))

  if [ ${#SELECTED_RUN_IDXS[@]} -eq 0 ]; then
    echo "  (no runs selected for this workflow)"
    continue
  fi

  KEY="${idx}_runs"
  RUNS_TO_DELETE[$KEY]=""
  for ridx in "${SELECTED_RUN_IDXS[@]}"; do
    RID=$(echo "${RUNS[$ridx]}" | jq -r '.databaseId')
    RUNS_TO_DELETE[$KEY]="${RUNS_TO_DELETE[$KEY]} $RID"
  done
done

echo ""
echo "Summary:"
for idx in "${SELECTED_IDXS[@]}"; do
  KEY="${idx}_runs"
  WF_NAME="${WF_NAMES[$idx]}"
  echo "  Workflow: $WF_NAME"
  if [ -n "${RUNS_TO_DELETE[$KEY]:-}" ]; then
    for rid in ${RUNS_TO_DELETE[$KEY]}; do
      echo "    -> Run #$rid"
    done
  else
    echo "    (no runs to delete)"
  fi
  echo ""
done

read -rp "Confirm deletion? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

for idx in "${SELECTED_IDXS[@]}"; do
  KEY="${idx}_runs"
  WF_NAME="${WF_NAMES[$idx]}"
  WF_ID=$(echo "${WORKFLOWS[$idx]}" | jq -r '.id')

  echo ""
  echo "Processing: $WF_NAME"

  if [ -n "${RUNS_TO_DELETE[$KEY]:-}" ]; then
    echo "  Deleting runs..."
    for rid in ${RUNS_TO_DELETE[$KEY]}; do
      gh run delete --repo "$REPO" "$rid" && echo "    Deleted run #$rid"
    done
  fi

  if [ "${WF_ALL_RUNS[$idx]:-0}" = "1" ]; then
    read -rp "  All runs deleted. Disable workflow '$WF_NAME'? [y/N] " DISABLE_CONFIRM
    if [[ "$DISABLE_CONFIRM" =~ ^[Yy]$ ]]; then
      gh workflow disable "$WF_ID" --repo "$REPO" && echo "    Disabled $WF_NAME"
    fi
  fi
done

echo ""
echo "Done. Refresh your Actions page."