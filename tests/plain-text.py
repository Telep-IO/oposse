#!/usr/bin/env python3
"""Roster and notification strings are drawn as plain text.

Qt Text defaults to AutoText. A chat preview, bot name, title or section
name containing an HTML image tag makes Qt request that URL when the
roster is shown. Every Text (and Label, TextEdit, TextInput, TextArea)
whose text binding reads that data must set textFormat: Text.PlainText.

The bar tooltip is Omarchy's Text, so Widget.qml escapes a tooltip that
contains "<" instead of setting textFormat there.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
KINDS = ("TextArea", "TextEdit", "TextInput", "Label", "Text")
UNTRUSTED = re.compile(
    r"root\.label\s*\(|last_text|\.name\b|\.title\b|\.description\b|"
    r"\bopening\b|\.version\b|barTooltip"
)
failures = []


def check(cond, message):
    if not cond:
        failures.append(message)


def skip_string(src, i):
    quote = src[i]
    i += 1
    n = len(src)
    while i < n:
        if src[i] == "\\":
            i += 2
            continue
        if src[i] == quote:
            return i + 1
        i += 1
    return n


def skip_ws_and_comments(src, i):
    n = len(src)
    while i < n:
        if src[i] in " \t\r\n":
            i += 1
            continue
        if src.startswith("//", i):
            nl = src.find("\n", i)
            i = n if nl < 0 else nl + 1
            continue
        if src.startswith("/*", i):
            end = src.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        break
    return i


def match_brace(src, open_at):
    """src[open_at] is '{'. Return the index one past the matching '}'."""
    depth = 0
    i = open_at
    n = len(src)
    while i < n:
        if src.startswith("//", i):
            nl = src.find("\n", i)
            i = n if nl < 0 else nl + 1
            continue
        if src.startswith("/*", i):
            end = src.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        c = src[i]
        if c in "\"'`":
            i = skip_string(src, i)
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced brace at %s" % open_at)


def next_is_property(src, i):
    i = skip_ws_and_comments(src, i)
    return re.match(r"[A-Za-z_][\w.]*\s*:", src[i:]) is not None


def end_of_binding(src, start):
    if start < len(src) and src[start] == "{":
        return match_brace(src, start)
    i = start
    n = len(src)
    paren = bracket = brace = 0
    while i < n:
        if src.startswith("//", i):
            nl = src.find("\n", i)
            if paren == bracket == brace == 0 and next_is_property(src, n if nl < 0 else nl + 1):
                return i
            i = n if nl < 0 else nl + 1
            continue
        if src.startswith("/*", i):
            end = src.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        c = src[i]
        if c in "\"'`":
            i = skip_string(src, i)
            continue
        if c == "(":
            paren += 1
        elif c == ")":
            paren = max(0, paren - 1)
        elif c == "[":
            bracket += 1
        elif c == "]":
            bracket = max(0, bracket - 1)
        elif c == "{":
            brace += 1
        elif c == "}":
            if paren == bracket == brace == 0:
                return i
            brace = max(0, brace - 1)
        elif c == "\n" and paren == bracket == brace == 0 and next_is_property(src, i + 1):
            return i
        i += 1
    return n


def top_level_props(body):
    props = []
    i = 0
    n = len(body)
    while i < n:
        i = skip_ws_and_comments(body, i)
        if i >= n:
            break
        match = re.match(r"[A-Za-z_][\w.]*", body[i:])
        if not match:
            if body[i] in "\"'`":
                i = skip_string(body, i)
            else:
                i += 1
            continue
        name = match.group(0)
        j = skip_ws_and_comments(body, i + len(name))
        if j < n and body[j] == ":":
            j = skip_ws_and_comments(body, j + 1)
            val_end = end_of_binding(body, j)
            props.append((name, body[j:val_end]))
            i = val_end
            continue
        i += len(name)
    return props


def text_blocks(src):
    """Yield (kind, line, body) for each Text-like element. Nested ones too."""
    blocks = []
    i = 0
    n = len(src)
    while i < n:
        if src.startswith("//", i):
            nl = src.find("\n", i)
            i = n if nl < 0 else nl + 1
            continue
        if src.startswith("/*", i):
            end = src.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        if src[i] in "\"'`":
            i = skip_string(src, i)
            continue
        if src[i].isalpha() or src[i] == "_":
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            word = src[i:j]
            if word in KINDS:
                k = skip_ws_and_comments(src, j)
                if k < n and src[k] == "{":
                    end = match_brace(src, k)
                    line = src.count("\n", 0, i) + 1
                    blocks.append((word, line, src[k + 1:end - 1]))
            i = j
            continue
        i += 1
    return blocks


def plain_text_problems(src, path):
    """Return messages for Text-like items that show untrusted text unsafely."""
    problems = []
    guarded = []
    for kind, line, body in text_blocks(src):
        props = top_level_props(body)
        texts = [value for name, value in props if name == "text"]
        if not texts or not UNTRUSTED.search(texts[-1]):
            continue
        formats = [value.strip() for name, value in props if name == "textFormat"]
        where = "%s:%s %s" % (path, line, kind)
        if formats and formats[-1] == "Text.PlainText":
            guarded.append(where)
            continue
        got = formats[-1] if formats else "Text.AutoText (default)"
        problems.append("%s shows untrusted text as %s" % (where, got))
    return problems, guarded


def qml_files():
    found = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [name for name in dirnames if name not in (".git",)]
        for name in filenames:
            if name.endswith(".qml"):
                found.append(os.path.join(dirpath, name))
    return sorted(found)


def test_scanner():
    bad = """
    Text {
      text: modelData.bot.last_text
      color: "white"
    }
    Text { text: "static label" }
    Text {
      textFormat: Text.RichText
      text: root.label(modelData.name)
    }
    Text {
      text: modelData.kind === "bot"
        ? root.label(modelData.bot.title)
        : ""
      color: "dim"
    }
    """
    problems, guarded = plain_text_problems(bad, "fixture")
    check(len(problems) == 3, "scanner missed a bad fixture: %s" % problems)
    check(guarded == [], "scanner treated a bad fixture as guarded: %s" % guarded)

    good = """
    Item {
      Text {
        text: "no assistants"
      }
      Text {
        text: root.label(modelData.bot.last_text)
        textFormat: Text.PlainText
      }
      Rectangle {
        Text {
          textFormat: Text.PlainText
          text: root.opening + root.app.version
        }
      }
    }
    """
    problems, guarded = plain_text_problems(good, "fixture")
    check(problems == [], "scanner rejected a plain-text fixture: %s" % problems)
    check(len(guarded) == 2, "scanner lost a guarded fixture: %s" % guarded)


def test_repo():
    guarded = []
    for path in qml_files():
        rel = os.path.relpath(path, ROOT)
        text = open(path, encoding="utf-8").read()
        problems, found = plain_text_problems(text, rel)
        for message in problems:
            check(False, message)
        guarded.extend(found)
    check(len(guarded) >= 5, "expected the roster texts to be plain, found %s" % guarded)

    widget = open(os.path.join(ROOT, "Widget.qml"), encoding="utf-8").read()
    start = widget.find("function tooltipText")
    check(start >= 0, "tooltipText is missing")
    if start >= 0:
        end = widget.find("\n  readonly property string barTooltip:", start)
        body = widget[start:end if end >= 0 else start]
        amp = body.find('replace(/&/g, "&amp;")')
        lt = body.find('replace(/</g, "&lt;")')
        gt = body.find('replace(/>/g, "&gt;")')
        check('indexOf("<")' in body and 'indexOf("\\n")' in body,
              "tooltipText no longer limits escaping to a first-line <")
        check(0 <= amp < lt < gt, "tooltipText must escape & before < and >")
    tip = widget.find("readonly property string barTooltip:")
    check(tip >= 0, "barTooltip is missing")
    if tip >= 0:
        tip_end = widget.find("\n  implicitWidth:", tip)
        tip_body = widget[tip:tip_end if tip_end >= 0 else tip + 500]
        wrapped = re.search(r"return\s+tooltipText\((.*)\)\s*$", tip_body, re.M)
        check(wrapped is not None and ".name" in wrapped.group(1),
              "barTooltip passes a bot name to the bar without tooltipText")
    check("showTooltip(row, root.barTooltip)" in widget, "bar tooltip is no longer barTooltip")


def main():
    test_scanner()
    test_repo()
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
