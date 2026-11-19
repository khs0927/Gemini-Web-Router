#!/usr/bin/env python3
"""
Gemini Web Router — Dedicated MCP Server for Claude Code & Antigravity IDE
==========================================================================
Exposes `gemini.google.com` Pro quota (via local port 8766 router) directly as native MCP tools:
- `gemini_web_ask`: Ask Gemini 4 Carbon / Neon / Hydrogen / Auto with optional reasoning effort
- `gemini_web_quota`: Check real-time 5-hour (2400) & weekly (48,380) remaining credits on gemini.google.com
- `gemini_web_models`: List all available Gemini Web models and aliases
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any

ROUTER_BASE = os.environ.get("GEMINI_WEB_ROUTER_URL", "http://127.0.0.1:8766").rstrip("/")
API_KEY = os.environ.get("GEMINI_WEB_API_KEY", "local-dev-token")

TOOLS = [
    {
        "name": "gemini_web_ask",
        "description": (
            "Send a prompt to Google Gemini Web Router (gemini.google.com Pro quota on port 8766). "
            "Models: 'gemini-4-carbon' (default, coding & complex tasks), 'gemini-4-neon' (deep analysis), "
            "'gemini-4-hydrogen' (fast general), 'gemini-auto' (dynamic routing)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "prompt": {
                    "type": "string",
                    "description": "Self-contained prompt to send to Gemini Web",
                },
                "model": {
                    "type": "string",
                    "enum": ["gemini-4-carbon", "gemini-4-neon", "gemini-4-hydrogen", "gemini-auto"],
                    "description": "Target Gemini Web model (default: gemini-4-carbon)",
                },
                "system": {
                    "type": "string",
                    "description": "Optional system instructions",
                },
                "reasoning_effort": {
                    "type": "string",
                    "enum": ["low", "medium", "high", "xhigh"],
                    "description": "Optional thinking effort level",
                },
            },
            "required": ["prompt"],
        },
    },
    {
        "name": "gemini_web_quota",
        "description": "Check real-time gemini.google.com 5-hour window (2400 credits) and weekly (48,380 credits) remaining quota.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "refresh": {
                    "type": "boolean",
                    "description": "Force live RPC quota refresh from gemini.google.com",
                }
            },
        },
    },
    {
        "name": "gemini_web_models",
        "description": "List available models and live status from Gemini Web Router.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
]


def http_json(method: str, path: str, body: dict[str, Any] | None = None, timeout: int = 240) -> tuple[dict[str, Any], dict[str, str]]:
    url = f"{ROUTER_BASE}{path}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_KEY}",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        headers = {k.lower(): v for k, v in resp.headers.items()}
        return json.loads(raw), headers


def call_tool(name: str, args: dict[str, Any]) -> dict[str, Any]:
    if name == "gemini_web_quota":
        refresh = "true" if args.get("refresh") else "false"
        data, _ = http_json("GET", f"/v1/usage?refresh={refresh}", timeout=30)
        return {"content": [{"type": "text", "text": json.dumps(data, indent=2, ensure_ascii=False)}]}

    if name == "gemini_web_models":
        data, _ = http_json("GET", "/v1/models", timeout=30)
        return {"content": [{"type": "text", "text": json.dumps(data, indent=2, ensure_ascii=False)}]}

    if name == "gemini_web_ask":
        prompt = args.get("prompt") or ""
        model = args.get("model") or "gemini-4-carbon"
        system = args.get("system")
        effort = args.get("reasoning_effort")

        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        payload: dict[str, Any] = {
            "model": model,
            "messages": messages,
            "stream": False,
        }
        if effort:
            payload["reasoning_effort"] = effort

        data, hdrs = http_json("POST", "/v1/chat/completions", payload, timeout=300)
        choice = (data.get("choices") or [{}])[0]
        msg = choice.get("message") or {}
        content = msg.get("content") or ""
        reasoning = msg.get("reasoning_content") or ""
        rem_5h = hdrs.get("x-gemini-remaining-5h", "?")
        rem_wk = hdrs.get("x-gemini-remaining-weekly", "?")
        resolved = hdrs.get("x-gemini-resolved-model", model)

        header = f"[Gemini Web: {resolved} | 5h Quota: {rem_5h}/2400 | Weekly: {rem_wk}]"
        if reasoning:
            out_text = f"{header}\n\n<thinking>\n{reasoning}\n</thinking>\n\n{content}"
        else:
            out_text = f"{header}\n\n{content}"
        return {"content": [{"type": "text", "text": out_text}]}

    raise ValueError(f"Unknown tool: {name}")


def send_msg(msg: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue

        msg_id = req.get("id")
        method = req.get("method")
        params = req.get("params") or {}

        if msg_id is None:
            continue

        if method == "initialize":
            send_msg(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "protocolVersion": params.get("protocolVersion", "2024-11-05"),
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "gemini-web", "version": "1.2.0"},
                    },
                }
            )
        elif method == "ping":
            send_msg({"jsonrpc": "2.0", "id": msg_id, "result": {}})
        elif method == "tools/list":
            send_msg({"jsonrpc": "2.0", "id": msg_id, "result": {"tools": TOOLS}})
        elif method == "tools/call":
            tname = params.get("name", "")
            targs = params.get("arguments") or {}
            try:
                res = call_tool(tname, targs)
                send_msg({"jsonrpc": "2.0", "id": msg_id, "result": res})
            except Exception as e:
                send_msg(
                    {
                        "jsonrpc": "2.0",
                        "id": msg_id,
                        "result": {
                            "content": [{"type": "text", "text": f"Error calling {tname}: {e}"}],
                            "isError": True,
                        },
                    }
                )
        else:
            send_msg(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"},
                }
            )


if __name__ == "__main__":
    main()
