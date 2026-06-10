#!/usr/bin/env python3
"""
llm_grammar - Local LLM grammar checker via llama.cpp server
===========================================================
A lightweight wrapper to call a local llama.cpp server for grammar checking.
Supports custom prompts, stdin input, and configurable endpoints.

Usage examples:
--------------
# Check a single sentence with default prompt
uv run llm_grammar.py --input "The quikc brown fox jumps over the lazey dog"

# Use a custom prompt and specific model
uv run llm_grammar.py \
  --model gemma-2b-coedit \
  --prompt "You are an editor. Fix grammar and spelling only, no extra comments." \
  --input "She dont like apples."

# Read from stdin (pipe input)
echo "He go to school every day." | uv run llm_grammar.py --stdin
cat essay.txt | uv run llm_grammar.py --stdin --host http://localhost:8081
"""

import argparse
import sys
import requests


def main():
    parser = argparse.ArgumentParser(
        description="Local LLM grammar checker via llama.cpp server",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage examples:")[1]  # 复用文档中的示例
    )

    # 核心参数（无硬编码，全部可配置）
    parser.add_argument(
        "--model",
        help="Model identifier (optional; depends on your llama.cpp server config)"
    )
    parser.add_argument(
        "--prompt",
        default="You are a professional English teacher. Perform spell check and improve grammar if necessary. Fix grammar in the following text:",
        help="Custom system prompt for grammar checking (default: built-in grammar prompt)"
    )
    parser.add_argument(
        "--input", "-i",
        help="Input text to check (mutually exclusive with --stdin)"
    )
    parser.add_argument(
        "--host",
        default="http://127.0.0.1:8080",
        help="llama.cpp server endpoint (default: http://127.0.0.1:8080)"
    )
    parser.add_argument(
        "--stdin",
        action="store_true",
        help="Read input from standard input (for piping data)"
    )

    args = parser.parse_args()

    # 输入验证：必须二选一
    if args.stdin and args.input:
        parser.error("Cannot use both --input and --stdin")
    if not args.stdin and not args.input:
        parser.error("Either --input or --stdin must be provided")

    # 读取输入内容
    if args.stdin:
        input_text = sys.stdin.read().strip()
    else:
        input_text = args.input.strip()

    if not input_text:
        parser.error("Input text cannot be empty")

    # 构造 llama.cpp server 的 chat completion 请求（兼容 gemma 的 chat template）
    url = f"{args.host}/chat/completions"
    headers = {"Content-Type": "application/json"}
    payload = {
        "messages": [
            {"role": "system", "content": args.prompt},
            {"role": "user", "content": input_text}
        ],
        "temperature": 0.3,  # 低温度适合语法修正任务
        "max_tokens": 512,
        "stream": False
    }

    # 可选：添加模型参数（如果服务器支持动态切换）
    if args.model:
        payload["model"] = args.model

    try:
        # 发送请求到本地 llama.cpp server
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()  # 捕获 HTTP 错误（如 404/500）

        # 解析响应（llama.cpp 的 /chat/completions 格式）
        result = response.json()
        corrected_text = result["choices"][0]["message"]["content"].strip()

        # 输出结果（纯净，无额外日志）
        print(corrected_text)

    except requests.exceptions.ConnectionError:
        print(f"❌ Error: Could not connect to llama.cpp server at {args.host}", file=sys.stderr)
        print("   Make sure the server is running (e.g., `./llama-server -m your_model.gguf`)", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"❌ HTTP Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyError:
        print("❌ Error: Unexpected response format from server", file=sys.stderr)
        print("   Ensure you're using llama.cpp server with /chat/completions support", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()