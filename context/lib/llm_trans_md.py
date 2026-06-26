# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
#     "langdetect",
#     "iso639-lang",
# ]
# ///

# llm_trans_md — Translate Markdown/TXT files via local LLM, preserving formatting
#
# Markdown placeholder/tokenization strategy adapted from:
#   https://github.com/rockbenben/md-translator
#
# Built-in defaults:
#   LLM_TRANS_MODEL=translategemma-12b-it-i1
#   LLM_TRANS_SRC=en
#   LLM_TRANS_TGT=zh
# Precedence: --args > ENV > built-in defaults
#
# ── Model language support ────────────────────────────────────────────────────
#
# gemma-3-12b-it
#   Model card claims 140+ languages; quality varies significantly.
#   https://ai.google.dev/gemma/core/cards/gemma-3
#   NOTE: The GGUF model running locally may differ from the cloud version.
#   The 140+ figure describes Google's API endpoint, not necessarily the
#   local checkpoint. Verify with your GGUF if a specific language works.
#
# translategemma-12b-it-i1
#   Trained on ~30 high-resource languages for translation-specific tasks.
#   Model card: https://ai.google.dev/gemma/core/translate-gemma
#   Known supported (ISO 639-1):
#     ar (Arabic)         cs (Czech)        da (Danish)       de (German)
#     el (Greek)          en (English)      es (Spanish)      fi (Finnish)
#     fr (French)         he (Hebrew)       hi (Hindi)        hu (Hungarian)
#     id (Indonesian)     it (Italian)      ja (Japanese)     ko (Korean)
#     nl (Dutch)          no (Norwegian)    pl (Polish)       pt (Portuguese)
#     ro (Romanian)       ru (Russian)      sv (Swedish)      th (Thai)
#     tr (Turkish)        uk (Ukrainian)    vi (Vietnamese)   zh (Chinese)
#   Chinese dialects: zh (Simplified), zh-tw (Traditional).
#
#   To verify your GGUF supports a language, check the tokenizer vocabulary
#   or test with a short sentence via the llama.cpp /v1/chat/completions API.

import os
import re
import sys
import time
import json
import signal
import subprocess

import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'lib'))
from llm_utils.llm_common import call_llamacpp, normalize_text

from langdetect import detect, DetectorFactory
from iso639 import Lang

DetectorFactory.seed = 0

_INTERRUPTED = False


def _signal_handler(signum, frame):
    global _INTERRUPTED
    _INTERRUPTED = True
    print("\nInterrupt received, stopping...", file=sys.stderr)


# ════════════════════════════════════════════════════════════════════════════
# Language handling — accept ISO code (zh), ISO3 (zho), or name (Chinese)
# ════════════════════════════════════════════════════════════════════════════

def base_lang(code):
    return code.split('-')[0].lower()


def detect_lang(text):
    try:
        return detect(text)
    except Exception:
        return 'en'


# Manual overrides for names that iso639 doesn't recognize (e.g. "Simplified Chinese")
_NAME_OVERRIDES = {
    'simplified chinese': 'zh',
    'simplified-chinese': 'zh',
    'traditional chinese': 'zh-tw',
    'traditional-chinese': 'zh-tw',
}

# zh region suffixes that mean Traditional Chinese (preserve as zh-tw)
_ZH_TRADITIONAL_REGIONS = {'tw', 'hk', 'mo', 'hant'}
# zh region suffixes that mean Simplified Chinese (normalize to zh)
_ZH_SIMPLIFIED_REGIONS = {'cn', 'hans', 'sg'}


def lang_label(code):
    """Convert any language code to a human-readable name for the prompt."""
    base = base_lang(code)
    try:
        name = Lang(base).name
    except Exception:
        return code
    if base == 'zh' and '-' in code:
        region = code.split('-', 1)[1].lower()
        if region in _ZH_TRADITIONAL_REGIONS:
            return 'Traditional Chinese'
    return name


def parse_lang_input(token):
    """Normalize user input (zh, zho, Chinese, chinese, zh-tw) to an ISO code.

    For zh variants: zh-tw/hk/mo/hant → zh-tw (Traditional), zh-cn/hans/sg → zh (Simplified).
    """
    if token is None:
        return None
    t = token.strip()
    if not t:
        return None
    tl = t.lower()
    if tl == 'auto':
        return 'auto'

    # Check manual name overrides first (handles "Simplified Chinese", "Traditional Chinese")
    if tl in _NAME_OVERRIDES:
        return _NAME_OVERRIDES[tl]

    has_dash = '-' in tl
    if has_dash:
        base = tl.split('-')[0]
        region = tl.split('-', 1)[1]
    else:
        base = tl
        region = None

    try:
        pt1 = Lang(base).pt1
    except Exception:
        try:
            pt1 = Lang(t.title()).pt1
        except Exception:
            return base

    # Handle zh region variants
    if pt1 == 'zh' and has_dash and region:
        if region in _ZH_TRADITIONAL_REGIONS:
            return 'zh-tw'
        if region in _ZH_SIMPLIFIED_REGIONS:
            return 'zh'
    return pt1


# ════════════════════════════════════════════════════════════════════════════
# Prompt presets — controls translation style and what to keep untranslated
# ════════════════════════════════════════════════════════════════════════════

PROMPTS = {
    "default": {
        "system": (
            "You are a translator. Translate the user's text from {src_lang} into {tgt_lang}.\n"
            "Rules:\n"
            "1. Translate naturally and faithfully. Do not embellish or rewrite.\n"
            "2. Do NOT translate technical terms, terminology, proper nouns, "
            "API names, library names, function names, CSS properties, HTML tags, "
            "command names, or domain-specific jargon. Keep them in their original form.\n"
            "3. Output ONLY the translated text. No explanations, no notes, no preamble."
        ),
        "user": "Translate from {src_lang} into {tgt_lang}.\n\n{text}",
    },
    "literal": {
        "system": (
            "You are a translator. Translate the user's text from {src_lang} into {tgt_lang}.\n"
            "Rules:\n"
            "1. Translate word-for-word as faithfully as possible. Do not paraphrase or polish.\n"
            "2. Do NOT translate technical terms, terminology, proper nouns, code identifiers, "
            "or domain-specific jargon. Keep them in their original form.\n"
            "3. Output ONLY the translated text. No explanations, no notes, no preamble."
        ),
        "user": "Translate from {src_lang} into {tgt_lang}.\n\n{text}",
    },
    "fluent": {
        "system": (
            "You are a translator. Translate the user's text from {src_lang} into {tgt_lang}.\n"
            "Rules:\n"
            "1. Translate for natural readability in {tgt_lang}. You may adjust sentence structure "
            "for fluency, but keep the meaning faithful.\n"
            "2. Do NOT translate technical terms, terminology, proper nouns, code identifiers, "
            "or domain-specific jargon. Keep them in their original form.\n"
            "3. Output ONLY the translated text. No explanations, no notes, no preamble."
        ),
        "user": "Translate from {src_lang} into {tgt_lang}.\n\n{text}",
    },
}


# ════════════════════════════════════════════════════════════════════════════
# Markdown placeholder tokenizer
# ════════════════════════════════════════════════════════════════════════════

_PH_PAT = (
    r'<<<(?:FRONTMATTER_\d+|MULTILINE_CODE_\d+|LATEX_BLOCK_\d+'
    r'|CODE_\d+|LATEX_INLINE_\d+|LINK_PRE_\d+|LINK_SUF_\d+|LINK_\d+'
    r'|HEADING_\d+|LIST_\d+|BLOCKQUOTE_\d+|HTML_\d+)>>>'
)
PH_RE = re.compile(_PH_PAT)
PH_SPLIT = re.compile(r'(' + _PH_PAT + r')')
PH_EXACT = re.compile(r'^' + _PH_PAT + r'$')

_RE_FRONTMATTER = re.compile(r'^---\n[\s\S]*?\n---', re.MULTILINE)
_RE_CODE_BLOCK = re.compile(r'```[\s\S]*?```')
_RE_LATEX_BLOCK = re.compile(r'\$\$[\s\S]*?\$\$')
_RE_INLINE_CODE = re.compile(r'`([^`]+?)`')
_RE_LATEX_INLINE = re.compile(r'\$([^\$]+?)\$')
_RE_HTML_COMMENT = re.compile(r'<!--[\s\S]*?-->')
_RE_HTML_SELFCLOSE = re.compile(r'<([a-zA-Z][a-zA-Z0-9-]*)\s*[^>]*/>')
_RE_HTML_CLOSE = re.compile(r'</([a-zA-Z][a-zA-Z0-9-]*)>')
_RE_HTML_OPEN = re.compile(r'<([a-zA-Z][a-zA-Z0-9-]*)(?:\s+[^>]*)?>')
_RE_IMAGE = re.compile(r'(!\[)(.*?)(\]\(.*?\))')
_RE_LINK = re.compile(r'(\[)(.*?)(\]\(.*?\))')
_RE_HEADING = re.compile(r'^(#{1,6}\s)(.*)', re.MULTILINE)
_RE_LIST = re.compile(r'^(\s*(?:[-*]|\d+\.)\s+)(.*)', re.MULTILINE)
_RE_BLOCKQUOTE = re.compile(r'^(>\s)(.*)', re.MULTILINE)

_MD_EXTS = ('.md', '.markdown', '.mdx')


class _Tokenizer:
    def __init__(self, translate_link_text=True):
        self.placeholders = {}
        self._n = 100
        self._translate_link_text = translate_link_text

    def _ph(self, key):
        n = self._n
        self._n += 1
        return f'<<<{key.upper()}_{n}>>>'

    def _sub_block(self, text, key, pattern):
        def repl(m, _k=key):
            ph = self._ph(_k)
            self.placeholders[ph] = m.group(0)
            return ph
        return pattern.sub(repl, text)

    def tokenize(self, text):
        text = self._sub_block(text, 'FRONTMATTER', _RE_FRONTMATTER)
        text = self._sub_block(text, 'MULTILINE_CODE', _RE_CODE_BLOCK)
        text = self._sub_block(text, 'LATEX_BLOCK', _RE_LATEX_BLOCK)
        lines = text.split('\n')
        out = [self._sub_inline(line) for line in lines]
        return '\n'.join(out)

    def _sub_inline(self, line):
        line = self._sub_block(line, 'CODE', _RE_INLINE_CODE)
        line = self._sub_block(line, 'HTML', _RE_HTML_COMMENT)
        line = self._sub_block(line, 'HTML', _RE_HTML_SELFCLOSE)
        line = self._sub_block(line, 'HTML', _RE_HTML_CLOSE)
        line = self._sub_block(line, 'HTML', _RE_HTML_OPEN)

        def img_repl(m):
            content = m.group(2)
            if not content.strip():
                ph = self._ph('LINK')
                self.placeholders[ph] = m.group(0)
                return ph
            pre, suf = self._ph('LINK_PRE'), self._ph('LINK_SUF')
            self.placeholders[pre] = m.group(1)
            self.placeholders[suf] = m.group(3)
            return f'{pre}{content}{suf}'
        line = _RE_IMAGE.sub(img_repl, line)

        if self._translate_link_text:
            def link_repl(m):
                pre, suf = self._ph('LINK_PRE'), self._ph('LINK_SUF')
                self.placeholders[pre] = m.group(1)
                self.placeholders[suf] = m.group(3)
                return f'{pre}{m.group(2)}{suf}'
        else:
            def link_repl(m):
                ph = self._ph('LINK')
                self.placeholders[ph] = m.group(0)
                return ph
        line = _RE_LINK.sub(link_repl, line)

        def heading_repl(m):
            ph = self._ph('HEADING')
            self.placeholders[ph] = m.group(1)
            return f'{ph}{m.group(2)}'
        line = _RE_HEADING.sub(heading_repl, line)

        def list_repl(m):
            ph = self._ph('LIST')
            self.placeholders[ph] = m.group(1)
            return f'{ph}{m.group(2)}'
        line = _RE_LIST.sub(list_repl, line)

        def blockquote_repl(m):
            ph = self._ph('BLOCKQUOTE')
            self.placeholders[ph] = m.group(1)
            return f'{ph}{m.group(2)}'
        line = _RE_BLOCKQUOTE.sub(blockquote_repl, line)
        return line


def tokenize(text, translate_link_text=True):
    t = _Tokenizer(translate_link_text=translate_link_text)
    tokenized = t.tokenize(text)

    def latex_inline_repl(m):
        content = m.group(1)
        if re.match(r'^[\s\d,.]+$', content) and '\\' not in content:
            return m.group(0)
        ph = t._ph('LATEX_INLINE')
        t.placeholders[ph] = m.group(0)
        return ph
    tokenized = _RE_LATEX_INLINE.sub(latex_inline_repl, tokenized)
    return tokenized, t.placeholders


def restore(text, placeholders):
    return PH_RE.sub(lambda m: placeholders.get(m.group(0), m.group(0)), text)


def extract_translatable_segments(text):
    segments = []
    mappings = []
    for line in text.split('\n'):
        parts = PH_SPLIT.split(line)
        line_map = []
        for part in parts:
            if PH_EXACT.match(part):
                line_map.append(('ph', part))
            else:
                stripped = part.strip()
                if not stripped:
                    line_map.append(('empty', part))
                else:
                    idx = len(segments)
                    segments.append(stripped)
                    leading = part[:len(part) - len(part.lstrip())]
                    trailing = part[len(part.rstrip()):]
                    line_map.append(('text', idx, leading, trailing))
        mappings.append(line_map)
    return segments, mappings


def reassemble(mappings, translated):
    lines = []
    for line_map in mappings:
        parts = []
        for entry in line_map:
            if entry[0] == 'text':
                parts.append(f'{entry[2]}{translated[entry[1]]}{entry[3]}')
            else:
                parts.append(entry[1])
        lines.append(''.join(parts))
    return '\n'.join(lines)


# ════════════════════════════════════════════════════════════════════════════
# Postprocessing — deterministic CJK punctuation and spacing fixes
# ════════════════════════════════════════════════════════════════════════════

_CJK_LANG_CODES = {'zh', 'ja', 'ko'}


def is_cjk_target(tgt_lang_code):
    return base_lang(tgt_lang_code) in _CJK_LANG_CODES


_RE_CJK = re.compile(r'[\u4e00-\u9fff\u3400-\u4dbf]')

_HALF_TO_FULL = {
    ',': '\uff0c', '.': '\u3002', '?': '\uff1f', '!': '\uff01',
    ';': '\uff1b', ':': '\uff1a', '(': '\uff08', ')': '\uff09',
}
_FULL_PUNCT_CHARS = '\uff0c\u3002\uff1f\uff01\uff1b\uff1a\uff08\uff09\u201c\u201d'
_CJK_AND_CTX = r'\u4e00-\u9fff\u3400-\u4dbf' + _FULL_PUNCT_CHARS + '`'
_RE_PUNCT_AFTER_CJK = re.compile(r'([{}])([,.\?!;:])'.format(_CJK_AND_CTX))
_RE_PUNCT_BEFORE_CJK = re.compile(r'([,.\?!;:])([{}])'.format(_CJK_AND_CTX))
_RE_PAREN_AFTER_CJK = re.compile(r'([{}])([()])'.format(_CJK_AND_CTX))
_RE_PAREN_BEFORE_CJK = re.compile(r'([()])([{}])'.format(_CJK_AND_CTX))

_FULL_PUNCT = '\uff0c\u3002\uff1f\uff01\uff1b\uff1a\uff08\uff09\u201c\u201d'
_RE_FULL_PUNCT_SPACE = re.compile(
    r'([{}\u4e00-\u9fff\u3400-\u4dbf])\s+([{}\u4e00-\u9fff\u3400-\u4dbf])'.format(_FULL_PUNCT, _FULL_PUNCT)
)
_RE_PUNCT_TRAILING_SPACE = re.compile(r'([{}])[ \t]+'.format(_FULL_PUNCT))
_RE_PUNCT_LEADING_SPACE = re.compile(r'[ \t]+([{}])'.format(_FULL_PUNCT))


def postprocess(text):
    """Fix punctuation and spacing in CJK translation output.

    Only applied when CJK characters are present (target is CJK language).
    """
    if not text or not _RE_CJK.search(text):
        return text

    text = text.replace('\u3000', ' ')

    text = _RE_PUNCT_AFTER_CJK.sub(lambda m: m.group(1) + _HALF_TO_FULL[m.group(2)], text)
    text = _RE_PUNCT_BEFORE_CJK.sub(lambda m: _HALF_TO_FULL[m.group(1)] + m.group(2), text)
    text = _RE_PAREN_AFTER_CJK.sub(lambda m: m.group(1) + _HALF_TO_FULL[m.group(2)], text)
    text = _RE_PAREN_BEFORE_CJK.sub(lambda m: _HALF_TO_FULL[m.group(1)] + m.group(2), text)

    for _ in range(3):
        prev = text
        text = _RE_FULL_PUNCT_SPACE.sub(r'\1\2', text)
        text = _RE_PUNCT_TRAILING_SPACE.sub(r'\1', text)
        text = _RE_PUNCT_LEADING_SPACE.sub(r'\1', text)
        if text == prev:
            break

    text = re.sub(r'([\u4e00-\u9fff\u3400-\u4dbf])\s+([A-Za-z0-9`])', r'\1\2', text)
    text = re.sub(r'([A-Za-z0-9`])\s+([\u4e00-\u9fff\u3400-\u4dbf])', r'\1\2', text)

    return text


# ════════════════════════════════════════════════════════════════════════════
# LLM translation — dual model support
# ════════════════════════════════════════════════════════════════════════════

DEFAULT_HOST = "http://127.0.0.1:8010"
DEFAULT_MODEL = "translategemma-12b-it-i1"
DEFAULT_CONCURRENCY = 3
DEFAULT_TIMEOUT = 120
MAX_RETRIES = 3
RETRY_DELAYS = [1, 3, 8]

# Models that use TranslateGemma's translation-optimized prompt format
_TRANSLATEGEMMA_PREFIXES = ('translategemma',)


def is_translategemma(model_name):
    """Check if the model is a TranslateGemma variant (needs /completion endpoint)."""
    return model_name.lower().startswith(_TRANSLATEGEMMA_PREFIXES)


def _find_pid_by_port(host):
    port_match = re.search(r':(\d+)$', host)
    if not port_match:
        return None
    port = port_match.group(1)
    try:
        result = subprocess.run(
            ["netstat", "-ano"], capture_output=True, text=True, timeout=5
        )
        m = re.search(rf"127\.0\.0\.1:{port}\s+.*?LISTENING\s+(\d+)", result.stdout)
        return int(m.group(1)) if m else None
    except Exception:
        return None


def _kill_server(host):
    pid = _find_pid_by_port(host)
    if pid:
        try:
            subprocess.run(["taskkill", "/f", "/pid", str(pid)],
                           capture_output=True, timeout=5)
            print(f"  Killed server process (PID {pid})", file=sys.stderr)
        except Exception as e:
            print(f"  Failed to kill server: {e}", file=sys.stderr)
    else:
        print("  Server process not found", file=sys.stderr)


def _call_translategemma(text, src_lang_code, tgt_lang_code, model, host, timeout):
    """Call TranslateGemma via llama.cpp /v1/chat/completions.

    Uses a fill-in-the-blank prompt format ({src}: {text}\\n{tgt}:) that
    triggers direct translation continuation rather than explanatory mode.
    The server's built-in C formatter handles Gemma chat tokens.
    """
    src_label = lang_label(src_lang_code)
    tgt_label = lang_label(tgt_lang_code)
    prompt = (
        f"Translate from {src_label} to {tgt_label}.\n"
        f"Output ONLY the translated text. No explanation. No formatting.\n\n"
        f"{src_label}: {text}\n{tgt_label}:"
    )
    url = f"{host.rstrip('/')}/v1/chat/completions"
    payload = {
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        "max_tokens": 1024,
        "stream": False,
    }
    if model:
        payload["model"] = model
    last_err = None
    for attempt, delay_s in enumerate(RETRY_DELAYS, 1):
        try:
            resp = requests.post(
                url,
                headers={"Content-Type": "application/json; charset=utf-8"},
                data=json.dumps(payload).encode("utf-8", errors="replace"),
                timeout=timeout,
            )
            resp.raise_for_status()
            data = resp.json()
            choices = data.get("choices", [])
            if not choices:
                return ""
            raw = choices[0]["message"]["content"].strip()
            return normalize_text(raw) if raw else ""
        except Exception as e:
            last_err = e
            if attempt < MAX_RETRIES:
                time.sleep(delay_s)
    raise RuntimeError(f"TranslateGemma error after {MAX_RETRIES} retries: {last_err}")


def _call_gemma3(prompt, system_prompt, model, host, timeout, max_tokens=1024):
    """Call Gemma-3 (or any standard chat model) with plain text prompt."""
    last_err = None
    for attempt, delay_s in enumerate(RETRY_DELAYS, 1):
        try:
            raw = call_llamacpp(
                prompt, model, host, timeout,
                system_prompt=system_prompt,
                temperature=0.2,
                max_tokens=max_tokens,
            )
            return normalize_text(raw) if raw else ""
        except Exception as e:
            last_err = e
            if attempt < MAX_RETRIES:
                time.sleep(delay_s)
    raise RuntimeError(f"LLM error after {MAX_RETRIES} retries: {last_err}")


def translate_segments(segments, model, host, concurrency, timeout, prompt_preset, src_lang_code, tgt_lang_code, progress_cb=None):
    """Translate each segment independently via local LLM."""
    global _INTERRUPTED
    from concurrent.futures import ThreadPoolExecutor, as_completed

    use_tgemma = is_translategemma(model)
    total = len(segments)
    results = [None] * total
    done = 0

    if use_tgemma:
        # TranslateGemma: no system prompt, structured content
        def _do_one(idx, text):
            return idx, _call_translategemma(text, src_lang_code, tgt_lang_code, model, host, timeout)
    else:
        # Gemma-3: system prompt + user prompt template
        preset = PROMPTS[prompt_preset]
        src_label = lang_label(src_lang_code)
        tgt_label = lang_label(tgt_lang_code)
        system = preset["system"].replace("{src_lang}", src_label).replace("{tgt_lang}", tgt_label)
        user_tmpl = preset["user"]

        def _do_one(idx, text):
            prompt = user_tmpl.replace("{src_lang}", src_label).replace("{tgt_lang}", tgt_label).replace("{text}", text)
            return idx, _call_gemma3(prompt, system, model, host, timeout)

    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = {pool.submit(_do_one, i, seg): i for i, seg in enumerate(segments)}
        try:
            for future in as_completed(futures):
                if _INTERRUPTED:
                    break
                try:
                    idx, result = future.result()
                    results[idx] = result or segments[idx]
                except Exception as e:
                    idx = futures[future]
                    results[idx] = segments[idx]
                    print(f"\n  Warning: segment {idx} failed: {e}", file=sys.stderr)
                done += 1
                if progress_cb:
                    progress_cb(done, total)
        except KeyboardInterrupt:
            _INTERRUPTED = True
        for f in futures:
            f.cancel()
    for i in range(total):
        if results[i] is None:
            results[i] = segments[i]
    return results


# ════════════════════════════════════════════════════════════════════════════
# File processing
# ════════════════════════════════════════════════════════════════════════════

def translate_file(filepath, model, host, concurrency, timeout, prompt_preset, src_lang_code, tgt_lang_code, do_postprocess=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    ext = os.path.splitext(filepath)[1].lower()
    is_md = ext in _MD_EXTS

    if src_lang_code == 'auto':
        detected = detect_lang(content[:2000])
        src_lang_code = detected
        if detected == tgt_lang_code:
            print(f"  Detected source = target ({detected}), skipping.")
            return content

    if is_md:
        tokenized, placeholders = tokenize(content)
    else:
        tokenized, placeholders = content, {}

    pp = postprocess if (do_postprocess and is_cjk_target(tgt_lang_code)) else (lambda x: x)

    segments, mappings = extract_translatable_segments(tokenized)
    if not segments:
        print("  No translatable text found.")
        return content

    def progress(done, total):
        print(f"\r  Translating... {done}/{total}", end='', flush=True, file=sys.stderr)

    translated = translate_segments(segments, model, host, concurrency, timeout, prompt_preset, src_lang_code, tgt_lang_code, progress)
    print(file=sys.stderr)

    reassembled = reassemble(mappings, translated)
    result = restore(reassembled, placeholders) if is_md else reassembled
    return pp(result)


def main():
    global _INTERRUPTED
    import argparse
    signal.signal(signal.SIGINT, _signal_handler)
    parser = argparse.ArgumentParser(
        description='Translate Markdown/TXT files using local LLM (preserving formatting)')
    parser.add_argument('files', nargs='+', help='Files to translate (.md or .txt)')
    parser.add_argument('--host', default=DEFAULT_HOST,
                        help=f'llama.cpp server host (default: {DEFAULT_HOST})')
    parser.add_argument('--model', default=os.environ.get('LLM_TRANS_MODEL', DEFAULT_MODEL),
                        help=f'Model name (default: {DEFAULT_MODEL})')
    parser.add_argument('--src-lang', default=os.environ.get('LLM_TRANS_SRC', 'auto'),
                        help='Source language: ISO code (zh), ISO3 (zho), name (Chinese), or auto (default: auto)')
    parser.add_argument('--tgt-lang', default=os.environ.get('LLM_TRANS_TGT', 'zh'),
                        help='Target language: ISO code, ISO3, or name (default: zh)')
    parser.add_argument('--prompt', choices=list(PROMPTS.keys()), default='default',
                        help='Translation style preset (default: default)')
    parser.add_argument('--concurrency', '-c', type=int, default=DEFAULT_CONCURRENCY,
                        help=f'Max concurrent requests (default: {DEFAULT_CONCURRENCY})')
    parser.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT,
                        help=f'Request timeout in seconds (default: {DEFAULT_TIMEOUT})')
    parser.add_argument('--suffix', '-s', default=None,
                        help='Output filename suffix (default: .<tgt-lang>)')
    parser.add_argument('--no-postprocess', action='store_true',
                        help='Skip CJK punctuation/spacing postprocessing')
    parser.add_argument('--kill-server', action='store_true',
                        help='Kill llama-server process on interrupt/exit')
    parser.add_argument('--debug', action='store_true', help='Show debug info on stderr')
    args = parser.parse_args()

    src_lang_code = parse_lang_input(args.src_lang)
    tgt_lang_code = parse_lang_input(args.tgt_lang)

    if tgt_lang_code == 'auto':
        print("Error: target language cannot be 'auto'", file=sys.stderr)
        sys.exit(1)

    suffix = args.suffix or f'.{tgt_lang_code}'

    if args.debug:
        model_type = "TranslateGemma (/completion endpoint)" if is_translategemma(args.model) else "Standard chat (system + user prompt)"
        print(f"Host: {args.host}", file=sys.stderr)
        print(f"Model: {args.model}", file=sys.stderr)
        print(f"Model type: {model_type}", file=sys.stderr)
        print(f"Source: {src_lang_code}", file=sys.stderr)
        print(f"Target: {tgt_lang_code} ({lang_label(tgt_lang_code)})", file=sys.stderr)
        if not is_translategemma(args.model):
            print(f"Prompt: {args.prompt}", file=sys.stderr)
        print(f"Suffix: {suffix}", file=sys.stderr)

    error = 0
    total = len(args.files)
    try:
        for i, filepath in enumerate(args.files, 1):
            if _INTERRUPTED:
                error = 1
                break
            if not os.path.isfile(filepath):
                print(f"[{i}/{total}] Error: File not found: {filepath}")
                error = 1
                continue
            base, ext = os.path.splitext(filepath)
            outpath = f"{base}{suffix}{ext}"
            print(f"[{i}/{total}] {os.path.basename(filepath)}")
            try:
                result = translate_file(filepath, args.model, args.host,
                                        args.concurrency, args.timeout,
                                        args.prompt, src_lang_code, tgt_lang_code,
                                        do_postprocess=not args.no_postprocess)
                with open(outpath, 'w', encoding='utf-8') as f:
                    f.write(result)
                print(f"  -> {os.path.basename(outpath)}")
            except Exception as e:
                print(f"  Error: {e}")
                error = 1
    except KeyboardInterrupt:
        _INTERRUPTED = True
        error = 1
    finally:
        if args.kill_server:
            _kill_server(args.host)
    sys.exit(error)


if __name__ == '__main__':
    main()