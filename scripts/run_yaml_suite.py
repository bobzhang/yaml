#!/usr/bin/env python3
import base64
import json
import os
import re
import subprocess
import sys


REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
DATA_ROOT = os.path.join(REPO_ROOT, "yaml-test-suite-data")


def find_runner():
    env_runner = os.environ.get("YAML_SUITE_RUNNER")
    if env_runner and os.path.exists(env_runner):
        return env_runner
    candidates = [
        os.path.join(REPO_ROOT, "target", "native", "debug", "cmd", "yamlsuite", "yamlsuite"),
        os.path.join(REPO_ROOT, "target", "native", "release", "cmd", "yamlsuite", "yamlsuite"),
        os.path.join(REPO_ROOT, "target", "native", "release", "build", "cmd", "yamlsuite", "yamlsuite.exe"),
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


RUNNER = find_runner()

FLOAT_EPS = 1e-6


def run_cli(mode, data):
    payload = base64.b64encode(data).decode("ascii")
    if RUNNER:
        cmd = [RUNNER, mode, payload]
    else:
        cmd = ["moon", "run", "cmd/yamlsuite", "--", mode, payload]
    return subprocess.run(cmd, capture_output=True, text=True)


def unescape_event_value(text):
    text = text.replace("<SPC>", " ").replace("<TAB>", "\t")
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        i += 1
        if i >= len(text):
            out.append("\\")
            break
        esc = text[i]
        i += 1
        if esc == "n":
            out.append("\n")
        elif esc == "r":
            out.append("\r")
        elif esc == "t":
            out.append("\t")
        elif esc == "0":
            out.append("\0")
        elif esc == "\\":
            out.append("\\")
        elif esc == '"':
            out.append('"')
        elif esc == "'":
            out.append("'")
        elif esc == "x" and i + 1 < len(text):
            out.append(chr(int(text[i:i + 2], 16)))
            i += 2
        elif esc == "u" and i + 3 < len(text):
            out.append(chr(int(text[i:i + 4], 16)))
            i += 4
        elif esc == "U" and i + 7 < len(text):
            out.append(chr(int(text[i:i + 8], 16)))
            i += 8
        else:
            out.append(esc)
    return "".join(out)


def null_node():
    return {"type": "Null"}


def bool_node(value):
    return {"type": "Bool", "value": bool(value)}


def int_node(value):
    return {"type": "Int", "value": str(value)}


def float_node(value):
    if value != value:
        return {"type": "Float", "value": "nan"}
    if value == float("inf"):
        return {"type": "Float", "value": "inf"}
    if value == float("-inf"):
        return {"type": "Float", "value": "-inf"}
    return {"type": "Float", "value": value}


def float_equal(a, b):
    if isinstance(a, str) or isinstance(b, str):
        return a == b
    return abs(a - b) <= FLOAT_EPS


def compare_tree(a, b):
    if type(a) != type(b):
        return False
    if isinstance(a, dict):
        if a.get("type") != b.get("type"):
            return False
        node_type = a.get("type")
        if node_type == "Float":
            return float_equal(a.get("value"), b.get("value"))
        if node_type in ("Null",):
            return True
        if node_type in ("Bool", "Int", "String", "Binary", "Alias"):
            return a == b
        if node_type == "Anchor":
            return a.get("name") == b.get("name") and compare_tree(a.get("value"), b.get("value"))
        if node_type == "Tagged":
            return a.get("tag") == b.get("tag") and compare_tree(a.get("value"), b.get("value"))
        if node_type == "Seq":
            return compare_list(a.get("items"), b.get("items"))
        if node_type == "Map":
            return compare_list(a.get("items"), b.get("items"))
        return a == b
    if isinstance(a, list):
        return compare_list(a, b)
    return a == b


def compare_list(a_list, b_list):
    if a_list is None or b_list is None:
        return a_list == b_list
    if len(a_list) != len(b_list):
        return False
    for left, right in zip(a_list, b_list):
        if not compare_tree(left, right):
            return False
    return True


def compare_json_value(a, b):
    if type(a) != type(b):
        return False
    if isinstance(a, float):
        return float_equal(a, b)
    if isinstance(a, list):
        if len(a) != len(b):
            return False
        return all(compare_json_value(x, y) for x, y in zip(a, b))
    if isinstance(a, dict):
        if set(a.keys()) != set(b.keys()):
            return False
        return all(compare_json_value(a[k], b[k]) for k in a)
    return a == b


def string_node(value):
    return {"type": "String", "value": value}


def seq_node(items):
    return {"type": "Seq", "items": items}


def map_node(items):
    return {"type": "Map", "items": items}


def alias_node(name):
    return {"type": "Alias", "name": name}


def anchor_node(name, value):
    return {"type": "Anchor", "name": name, "value": value}


def tagged_node(tag, value):
    return {"type": "Tagged", "tag": tag, "value": value}


def wrap_props(node, anchor, tag):
    if tag:
        node = tagged_node(tag, node)
    if anchor:
        node = anchor_node(anchor, node)
    return node


def parse_scalar_value(raw):
    lowered = raw.lower()
    if lowered == "null" or raw == "~":
        return null_node()
    if lowered == "true":
        return bool_node(True)
    if lowered == "false":
        return bool_node(False)

    normalized = raw.replace("_", "")
    if not any(ch.isdigit() for ch in normalized):
        return string_node(raw)

    sign = 1
    body = normalized
    if normalized.startswith("-"):
        sign = -1
        body = normalized[1:]
    elif normalized.startswith("+"):
        body = normalized[1:]

    low_body = body.lower()
    if low_body in (".inf", "+.inf", "-.inf"):
        value = float("inf")
        if low_body.startswith("-"):
            value = float("-inf")
        return float_node(value)
    if low_body in (".nan", "+.nan", "-.nan"):
        return float_node(float("nan"))

    if body.startswith(("0x", "0X")):
        try:
            return int_node(int(body[2:], 16) * sign)
        except ValueError:
            return string_node(raw)
    if body.startswith(("0o", "0O")):
        try:
            return int_node(int(body[2:], 8) * sign)
        except ValueError:
            return string_node(raw)
    if body.startswith(("0b", "0B")):
        try:
            return int_node(int(body[2:], 2) * sign)
        except ValueError:
            return string_node(raw)

    if any(ch in normalized for ch in (".", "e", "E")):
        try:
            return float_node(float(normalized))
        except ValueError:
            return string_node(raw)

    try:
        return int_node(int(normalized))
    except ValueError:
        return string_node(raw)


def parse_event_scalar(style, raw):
    value = unescape_event_value(raw)
    if style in ("'", '"', "|", ">"):
        return string_node(value)
    return parse_scalar_value(value)


def parse_event_line(line):
    line = line.strip()
    if not line:
        return None
    if line.startswith("+") or line.startswith("-"):
        parts = line.split()
        kind = parts[0]
        tokens = parts[1:]
        return ("open" if kind[0] == "+" else "close", kind[1:], tokens)
    if line.startswith("=VAL"):
        rest = line[4:].strip()
        anchor = None
        tag = None
        style = ":"
        value = ""
        if rest:
            i = 0
            n = len(rest)
            while i < n:
                while i < n and rest[i].isspace():
                    i += 1
                if i >= n:
                    break
                if rest.startswith("[]", i) or rest.startswith("{}", i):
                    i += 2
                    continue
                if rest[i] == "&":
                    i += 1
                    start = i
                    while i < n and not rest[i].isspace():
                        i += 1
                    anchor = rest[start:i]
                    continue
                if rest[i] == "<":
                    i += 1
                    start = i
                    while i < n and rest[i] != ">":
                        i += 1
                    tag = rest[start:i]
                    if i < n and rest[i] == ">":
                        i += 1
                    continue
                if rest[i] == "!":
                    start = i
                    i += 1
                    while i < n and not rest[i].isspace():
                        i += 1
                    tag = rest[start:i]
                    continue
                style = rest[i]
                value = rest[i + 1:]
                break
        return ("scalar", anchor, tag, style, value)
    if line.startswith("=ALI"):
        rest = line[4:].strip()
        if rest.startswith("*"):
            return ("alias", rest[1:])
    return None


def parse_event_file(path):
    docs = []
    stack = []
    current_doc = None

    def push_node(node):
        nonlocal current_doc
        if not stack:
            current_doc = node
            return
        frame = stack[-1]
        if frame["kind"] == "seq":
            frame["items"].append(node)
        else:
            if frame["pending"] is None:
                frame["pending"] = node
            else:
                frame["items"].append([frame["pending"], node])
                frame["pending"] = None

    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            raw_line = raw_line.rstrip("\n")
            event = parse_event_line(raw_line)
            if event is None:
                continue
            kind = event[0]
            if kind == "open":
                ev_kind = event[1]
                tokens = event[2]
                if ev_kind == "STR":
                    continue
                if ev_kind == "DOC":
                    current_doc = None
                    continue
                if ev_kind == "MAP":
                    anchor, tag = parse_props(tokens)
                    stack.append({"kind": "map", "items": [], "pending": None, "anchor": anchor, "tag": tag})
                elif ev_kind == "SEQ":
                    anchor, tag = parse_props(tokens)
                    stack.append({"kind": "seq", "items": [], "anchor": anchor, "tag": tag})
                continue
            if kind == "close":
                ev_kind = event[1]
                if ev_kind == "STR":
                    continue
                if ev_kind == "DOC":
                    if current_doc is not None:
                        docs.append(current_doc)
                    current_doc = None
                    continue
                if ev_kind == "MAP":
                    frame = stack.pop()
                    node = map_node(frame["items"])
                    node = wrap_props(node, frame["anchor"], frame["tag"])
                    push_node(node)
                elif ev_kind == "SEQ":
                    frame = stack.pop()
                    node = seq_node(frame["items"])
                    node = wrap_props(node, frame["anchor"], frame["tag"])
                    push_node(node)
                continue
            if kind == "scalar":
                anchor, tag, style, value = event[1:]
                node = parse_event_scalar(style, value)
                node = wrap_props(node, anchor, tag)
                push_node(node)
            elif kind == "alias":
                push_node(alias_node(event[1]))

    if current_doc is not None:
        docs.append(current_doc)
    return docs


def parse_props(tokens):
    anchor = None
    tag = None
    for token in tokens:
        if token in ("[]", "{}"):
            continue
        if token.startswith("&"):
            anchor = token[1:]
            continue
        if token.startswith("<") and token.endswith(">"):
            tag = token[1:-1]
            continue
        if token.startswith("!") and len(token) > 0:
            tag = token
            continue
    return anchor, tag


def iter_tests():
    for entry in sorted(os.listdir(DATA_ROOT)):
        if entry in ("name", "tags"):
            continue
        path = os.path.join(DATA_ROOT, entry)
        if not os.path.isdir(path):
            continue
        subdirs = [d for d in os.listdir(path) if d.isdigit() and os.path.isdir(os.path.join(path, d))]
        if subdirs:
            for sub in sorted(subdirs):
                yield os.path.join(path, sub)
        else:
            yield path


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    decoder = json.JSONDecoder()
    idx = 0
    values = []
    while idx < len(text):
        while idx < len(text) and text[idx].isspace():
            idx += 1
        if idx >= len(text):
            break
        value, end = decoder.raw_decode(text, idx)
        values.append(value)
        idx = end
    if len(values) == 1:
        return values[0]
    return values


def main():
    if not os.path.isdir(DATA_ROOT):
        print("missing yaml-test-suite-data; run the clone step first", file=sys.stderr)
        return 2

    total = 0
    failures = []

    for test_dir in iter_tests():
        in_path = os.path.join(test_dir, "in.yaml")
        if not os.path.exists(in_path):
            continue
        with open(in_path, "rb") as handle:
            payload = handle.read()

        error_expected = os.path.exists(os.path.join(test_dir, "error"))
        event_path = os.path.join(test_dir, "test.event")
        json_path = os.path.join(test_dir, "in.json")

        total += 1

        if error_expected:
            result = run_cli("tree", payload)
            if result.returncode == 0:
                failures.append((test_dir, "expected error, got success"))
            continue

        if os.path.exists(event_path):
            expected_tree = parse_event_file(event_path)
            result = run_cli("tree", payload)
            if result.returncode != 0:
                failures.append((test_dir, "tree parse failed"))
            else:
                actual_tree = json.loads(result.stdout)
                if not compare_tree(actual_tree, expected_tree):
                    failures.append((test_dir, "tree mismatch"))

        if os.path.exists(json_path):
            expected_json = load_json(json_path)
            result = run_cli("json", payload)
            if result.returncode != 0:
                failures.append((test_dir, "json parse failed"))
            else:
                actual_json = json.loads(result.stdout)
                if not compare_json_value(actual_json, expected_json):
                    failures.append((test_dir, "json mismatch"))

    print(f"yaml-test-suite: {total} tests, {len(failures)} failed")
    for entry, reason in failures[:20]:
        print(f"- {entry}: {reason}")
    if failures:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
