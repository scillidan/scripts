# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///

# etytree - Etymology tree visualizer for the terminal.
# CLI port of https://github.com/agmmnn/etytree (Next.js web app).
# Reuses the same Etymology Explorer API endpoints and data parsing logic
# (autocomplete, get_trees, words/edges extraction from DataEty.tsx).
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Usage:
#   etytree <word>                  Show etymology tree in terminal
#   etytree <word> --no-color       Plain text without ANSI colors
#   etytree <word> --reverse        Roots at top, queried word below
#   etytree <word> --no-cache       Skip cache, fetch fresh data
#
# Data source: https://api.etymologyexplorer.com/prod/

import argparse
import hashlib
import json
import ssl
import sys
import time
import urllib.request
import urllib.parse
import urllib.error
from collections import defaultdict
from pathlib import Path
from html import escape as html_escape

API_BASE = "https://api.etymologyexplorer.com/prod"
USER_AGENT = "etytree-cli/1.0"
MAX_RETRIES = 2
RETRY_DELAY = 1.0
_DOTDIR = Path(__file__).resolve().parent / ".etytree_cli"

_X = "\u251c\u2500\u2500 "
_L = "\u2514\u2500\u2500 "
_V = "\u2502   "
_S = "    "


def _cache_dir():
    _DOTDIR.mkdir(parents=True, exist_ok=True)
    return _DOTDIR


def _cache_key(prefix, *parts):
    h = hashlib.sha256("|".join(str(p) for p in parts).encode()).hexdigest()[:16]
    return _cache_dir() / f"{prefix}_{h}.json"


def _cache_read(path):
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text("utf-8"))["v"]
    except (json.JSONDecodeError, KeyError, OSError):
        return None


def _cache_write(path, value):
    try:
        path.write_text(json.dumps({"v": value}), "utf-8")
    except OSError:
        pass


def api_get(path, params=None):
    url = API_BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_err = None
    for attempt in range(MAX_RETRIES + 1):
        try:
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
                return json.loads(resp.read())
        except (urllib.error.URLError, ssl.SSLError) as e:
            last_err = e
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_DELAY)
    raise last_err


def autocomplete(word, language="English", use_cache=True):
    ck = _cache_key("ac", word, language)
    if use_cache:
        hit = _cache_read(ck)
        if hit is not None:
            return (int(hit[0]), hit[1]) if hit else None

    data = api_get("/autocomplete", {"word": word, "language": language})
    items = data.get("auto_complete_data", [])
    result = [items[0]["_id"], items[0]["word"]] if items else None
    _cache_write(ck, result)
    return (int(result[0]), result[1]) if result else None


def get_tree(word_id, use_cache=True):
    ck = _cache_key("tree", word_id)
    if use_cache:
        hit = _cache_read(ck)
        if hit is not None:
            nodes = {int(k): v for k, v in hit["nodes"].items()}
            edges = [(int(a), int(b)) for a, b in hit["edges"]]
            return nodes, edges

    data = api_get("/get_trees", {"ids[]": word_id})
    if not isinstance(data, list) or len(data) < 4:
        return None, None
    words_raw = data[1].get("words", {})
    edges_raw = data[3] if isinstance(data[3], list) else []
    nodes = {}
    for _key, w in words_raw.items():
        wid = int(w["_id"])
        defs = _extract_definition(w)
        nodes[wid] = {
            "id": wid,
            "word": w.get("word", ""),
            "language": w.get("language_name", ""),
            "definition": defs,
        }
    edges = [(int(e[0]), int(e[1])) for e in edges_raw]
    result = {"nodes": nodes, "edges": edges}
    _cache_write(ck, result)
    return nodes, edges


def _extract_definition(w):
    entries = w.get("entries", {})
    if isinstance(entries, dict):
        for val in entries.values():
            try:
                pos = val.get("pos", {})
                if isinstance(pos, dict):
                    for pv in pos.values():
                        d = pv.get("definitions", [])
                        if d:
                            return d[0]
            except (AttributeError, IndexError, KeyError, TypeError):
                continue
    elif isinstance(entries, list):
        try:
            return entries[0]["pos"][0]["definitions"][0]
        except (IndexError, KeyError, TypeError):
            pass
    return ""


def build_tree(nodes, edges, reverse=False):
    children = defaultdict(list)
    has_parent = set()
    for src, dst in edges:
        if reverse:
            parent, child = src, dst
        else:
            parent, child = dst, src
        children[parent].append(child)
        has_parent.add(child)
    nids = set(nodes.keys())
    roots = [nid for nid in nids if nid not in has_parent]
    if not roots:
        roots = list(nids)
    return roots, children


def render_tree_terminal(nodes, roots, children, color=True, visited=None):
    if visited is None:
        visited = set()
    lines = []
    for i, root_id in enumerate(roots):
        is_last = i == len(roots) - 1
        connector = _L if is_last else _X
        node = nodes.get(root_id, {})
        label = _fmt_node(node, color)

        lines.append(f"{connector}{label}")

        if root_id in visited:
            child_prefix = _S if is_last else _V
            lines.append(f"{child_prefix}{_L}\u2026 (see above)")
            continue
        visited.add(root_id)

        child_prefix = _S if is_last else _V
        child_ids = children.get(root_id, [])
        if child_ids:
            sub = render_tree_terminal(nodes, child_ids, children, color, visited)
            for line in sub:
                lines.append(f"{child_prefix}{line}")
    return lines


def _fmt_node(node, color, max_def=80):
    word = node.get("word", "?")
    lang = node.get("language", "")
    defn = node.get("definition", "")
    label = word
    if lang:
        label += f" \033[36m({lang})\033[0m" if color else f" ({lang})"
    if defn:
        if len(defn) > max_def:
            defn = defn[: max_def - 3] + "..."
        label += f" \033[2m\u2014 {defn}\033[0m" if color else f" \u2014 {defn}"
    return label


def main():
    parser = argparse.ArgumentParser(
        prog="etytree",
        description="Etymology tree visualizer for the terminal",
    )
    parser.add_argument("word", help="Word to look up")
    parser.add_argument(
        "--lang", default="English", help="Language (default: English)"
    )
    parser.add_argument(
        "--no-color", action="store_true", help="Disable colored output (terminal mode)"
    )
    parser.add_argument(
        "--reverse", "-r", action="store_true",
        help="Reverse tree: roots at top, queried word at leaves",
    )
    parser.add_argument(
        "--no-cache", action="store_true", help="Skip cache, fetch fresh data from API"
    )
    args = parser.parse_args()

    use_cache = not args.no_cache

    try:
        result = autocomplete(args.word, args.lang, use_cache=use_cache)
    except (urllib.error.URLError, ssl.SSLError) as e:
        print(f"Network error: {e}", file=sys.stderr)
        sys.exit(1)

    if result is None:
        print(f"No results for '{args.word}'", file=sys.stderr)
        sys.exit(1)

    word_id, matched_word = result
    print(f"Found: {matched_word} (id={word_id})", file=sys.stderr)

    try:
        nodes, edges = get_tree(word_id, use_cache=use_cache)
    except (urllib.error.URLError, ssl.SSLError) as e:
        print(f"Network error: {e}", file=sys.stderr)
        sys.exit(1)

    if nodes is None:
        print(f"No etymology data for '{matched_word}'", file=sys.stderr)
        sys.exit(1)

    roots, children = build_tree(nodes, edges, reverse=args.reverse)

    color = not args.no_color
    direction = "roots \u2192 descendants" if args.reverse else "queried \u2192 roots"
    header = f"Etymology tree for {matched_word}  ({direction})"
    if color:
        header = f"\033[1m{header}\033[0m"
    lines = [header]
    lines.extend(render_tree_terminal(nodes, roots, children, color=color))
    output = "\n".join(lines) + "\n"

    sys.stdout.buffer.write(output.encode("utf-8"))


if __name__ == "__main__":
    main()
