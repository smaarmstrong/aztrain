#!/usr/bin/env python3
"""yamlmini -- a small, deterministic, safe YAML-subset loader.

Exists so pipeline-YAML graders (GitHub Actions, Azure Pipelines) can parse
learner YAML with NO third-party dependency (never imports PyYAML) and NO
arbitrary code execution (no tags resolve to Python objects; nothing is
eval'd or exec'd). Pure stdlib, single file, indentation-based recursive
parser. Deterministic: the same text always yields the same structure.

Supported subset
================

This is enough for real CI/CD YAML. Anything outside it raises a YamlError
naming the unsupported feature (with an approximate line number).

    * Block mappings      key: value, nested by indentation.
                          Indentation is SPACES only; a tab used for
                          indentation is an error.
    * Block sequences     - item, including sequences of mappings and
                          nested sequences.
    * Scalars             plain, single-quoted, and double-quoted.
                          Double quotes honour \\n \\t \\" \\\\ escapes;
                          single quotes are literal ('' -> ').
                          Type coercion on UNQUOTED plain scalars:
                              int          42, -7
                              float        1.0, 3.14, 1e3
                              bool         true/false/yes/no (any case)
                              null         null / ~ / (empty)
                          Everything else stays a string. QUOTED scalars are
                          always strings, so "1.0" and "0755" keep their text.
    * Block scalars       | (literal, newlines kept) and > (folded, lines
                          joined with spaces, blank lines -> newline). Chomp
                          indicators |- >- (strip) and |+ >+ (keep) honoured;
                          default clips to a single trailing newline.
    * Comments            # to end of line, EXCEPT inside quoted scalars.
    * Flow collections    one-line [a, b, c] and {a: 1, b: 2}; nesting such
                          as [[1,2],{k: v}] is supported.
    * Documents           a single document; a leading '---' and a trailing
                          '...' are ignored. A second '---' (multiple docs)
                          is an error -- load one document at a time.

Explicitly NOT supported (each errors clearly, naming the feature):
    * Anchors / aliases   & and *
    * Tags                !Type and !!type
    * Merge keys          <<
    * Multiple documents  a second '---'
    * Tab indentation

Keys are strings (a scalar key is coerced to its string form). Duplicate
keys in one mapping: last wins.

Public API:
    load(text)        -> dict/list/str/int/float/bool/None
    load_file(path)   -> same, reading a file
    dig(obj, *path)   -> value at a path of string keys / int indices, else None
    main()            -> CLI

CLI:
    python3 yamlmini.py <file.yml>            -- parsed structure as indented JSON
    python3 yamlmini.py <file.yml> --get a.b.0.c
                                              -- value at a dotted path
                                                 (numeric segments are list indices)
    Exit 0 on success, non-zero + a clear message on parse failure or a
    missing --get path.
"""

from __future__ import annotations

import json
import re
import sys

__all__ = ["load", "load_file", "dig", "main", "YamlError"]


class YamlError(Exception):
    """Any yamlmini parse failure."""


def _err(msg, line=None):
    where = f" (line {line})" if line else ""
    raise YamlError(f"yamlmini: {msg}{where}")


# ---------------------------------------------------------------------------
# Scalar typing
# ---------------------------------------------------------------------------

_INT_RE = re.compile(r"[-+]?[0-9]+$")
_FLOAT_RE = re.compile(
    r"[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$"
)
_NULLS = {"", "~", "null", "Null", "NULL"}
_TRUE = {"true", "True", "TRUE", "yes", "Yes", "YES"}
_FALSE = {"false", "False", "FALSE", "no", "No", "NO"}


def _coerce_plain(text):
    """Type an UNQUOTED plain scalar. Quoted scalars never reach here."""
    s = text.strip()
    if s in _NULLS:
        return None
    if s in _TRUE:
        return True
    if s in _FALSE:
        return False
    if _INT_RE.match(s):
        try:
            return int(s)
        except ValueError:  # pragma: no cover - regex already guards
            return s
    if _FLOAT_RE.match(s) and any(ch.isdigit() for ch in s):
        try:
            return float(s)
        except ValueError:  # pragma: no cover
            return s
    return s


# ---------------------------------------------------------------------------
# Quoted / plain scalar scanning (shared by flow and block parsers)
# ---------------------------------------------------------------------------

_DQ_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\", "/": "/", "0": "\0"}


def _scan_double(s, i, line):
    """Scan a double-quoted scalar starting at the opening quote."""
    out = []
    i += 1
    n = len(s)
    while i < n:
        c = s[i]
        if c == "\\" and i + 1 < n:
            out.append(_DQ_ESCAPES.get(s[i + 1], s[i + 1]))
            i += 2
            continue
        if c == '"':
            return i + 1, "".join(out)
        out.append(c)
        i += 1
    _err("unterminated double-quoted string", line)


def _scan_single(s, i, line):
    """Scan a single-quoted scalar starting at the opening quote ('' -> ')."""
    out = []
    i += 1
    n = len(s)
    while i < n:
        c = s[i]
        if c == "'":
            if i + 1 < n and s[i + 1] == "'":
                out.append("'")
                i += 2
                continue
            return i + 1, "".join(out)
        out.append(c)
        i += 1
    _err("unterminated single-quoted string", line)


def _strip_comment(text):
    """Remove a trailing '# ...' comment that is outside any quotes.

    A '#' only starts a comment when preceded by whitespace or at column 0,
    matching YAML: 'a#b' is the plain scalar a#b.
    """
    in_s = in_d = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if in_s:
            if c == "'":
                in_s = False
        elif in_d:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_d = False
        else:
            if c == "'":
                in_s = True
            elif c == '"':
                in_d = True
            elif c == "#" and (i == 0 or text[i - 1] in " \t"):
                return text[:i]
        i += 1
    return text


def _reject_unsupported(value, line):
    """Reject anchors, aliases, tags and merge keys naming the feature."""
    s = value.lstrip()
    if s.startswith("&"):
        _err("anchors ('&name') are not supported", line)
    if s.startswith("*"):
        _err("aliases ('*name') are not supported", line)
    if s.startswith("!"):
        _err("tags ('!type' / '!!type') are not supported", line)


# ---------------------------------------------------------------------------
# Flow collections: [a, b, c] and {a: 1, b: 2}, with simple nesting
# ---------------------------------------------------------------------------

class _Flow:
    def __init__(self, text, line):
        self.s = text
        self.i = 0
        self.n = len(text)
        self.line = line

    def _skip_ws(self):
        while self.i < self.n and self.s[self.i] in " \t":
            self.i += 1

    def parse(self):
        self._skip_ws()
        value = self._value()
        self._skip_ws()
        if self.i != self.n:
            _err(f"trailing characters in flow collection: {self.s[self.i:]!r}",
                 self.line)
        return value

    def _value(self):
        self._skip_ws()
        if self.i >= self.n:
            _err("unexpected end of flow collection", self.line)
        c = self.s[self.i]
        if c == "[":
            return self._seq()
        if c == "{":
            return self._map()
        return self._scalar(stop=",]}")

    def _seq(self):
        self.i += 1  # consume '['
        items = []
        self._skip_ws()
        if self.i < self.n and self.s[self.i] == "]":
            self.i += 1
            return items
        while True:
            items.append(self._value())
            self._skip_ws()
            if self.i >= self.n:
                _err("unterminated flow sequence '['", self.line)
            c = self.s[self.i]
            if c == "]":
                self.i += 1
                return items
            if c != ",":
                _err(f"expected ',' or ']' in flow sequence, got {c!r}", self.line)
            self.i += 1

    def _map(self):
        self.i += 1  # consume '{'
        out = {}
        self._skip_ws()
        if self.i < self.n and self.s[self.i] == "}":
            self.i += 1
            return out
        while True:
            key = self._scalar(stop=":,}")
            self._skip_ws()
            if self.i >= self.n or self.s[self.i] != ":":
                _err("expected ':' in flow mapping", self.line)
            self.i += 1
            val = self._value()
            out[_as_key(key)] = val
            self._skip_ws()
            if self.i >= self.n:
                _err("unterminated flow mapping '{'", self.line)
            c = self.s[self.i]
            if c == "}":
                self.i += 1
                return out
            if c != ",":
                _err(f"expected ',' or '}}' in flow mapping, got {c!r}", self.line)
            self.i += 1

    def _scalar(self, stop):
        self._skip_ws()
        if self.i >= self.n:
            return ""
        c = self.s[self.i]
        if c == '"':
            self.i, txt = _scan_double(self.s, self.i, self.line)
            return ("q", txt)
        if c == "'":
            self.i, txt = _scan_single(self.s, self.i, self.line)
            return ("q", txt)
        start = self.i
        while self.i < self.n and self.s[self.i] not in stop:
            self.i += 1
        raw = self.s[start:self.i].strip()
        _reject_unsupported(raw, self.line)
        return ("p", raw)


def _as_key(scalar):
    """A flow-scalar tuple ('q'|'p', text) -> string key."""
    return scalar[1]


def _flow_scalar_value(scalar):
    """A flow-scalar tuple -> typed Python value."""
    kind, text = scalar
    if kind == "q":
        return text
    return _coerce_plain(text)


# _Flow._value returns either a container or a scalar tuple; normalise.
def _flow_normalise(value):
    if isinstance(value, tuple):
        return _flow_scalar_value(value)
    if isinstance(value, list):
        return [_flow_normalise(v) for v in value]
    if isinstance(value, dict):
        return {k: _flow_normalise(v) for k, v in value.items()}
    return value


def _parse_flow(text, line):
    return _flow_normalise(_Flow(text, line).parse())


# ---------------------------------------------------------------------------
# Scalar-value dispatch (the RHS of a `key:` or a `-` item, on one line)
# ---------------------------------------------------------------------------

def _parse_inline_value(text, line):
    """Parse a single-line value: flow, quoted, or plain-with-coercion."""
    s = text.strip()
    if s == "":
        return None
    _reject_unsupported(s, line)
    if s[0] in "[{":
        return _parse_flow(s, line)
    if s[0] == '"':
        end, val = _scan_double(s, 0, line)
        if s[end:].strip():
            _err(f"trailing characters after quoted scalar: {s[end:]!r}", line)
        return val
    if s[0] == "'":
        end, val = _scan_single(s, 0, line)
        if s[end:].strip():
            _err(f"trailing characters after quoted scalar: {s[end:]!r}", line)
        return val
    return _coerce_plain(s)


# ---------------------------------------------------------------------------
# Line model
# ---------------------------------------------------------------------------

class _Line:
    __slots__ = ("indent", "content", "num")

    def __init__(self, indent, content, num):
        self.indent = indent      # number of leading spaces
        self.content = content    # comment-stripped, right-stripped body
        self.num = num            # 1-based source line number


def _prepare_lines(text):
    """Split into logical lines, tracking indent; blank/comment lines dropped.

    Raw lines are retained separately for block scalars (which need original
    indentation and content), so we return (lines, raw) where raw is the list
    of untouched source lines (0-based indexable by num-1).
    """
    raw = text.split("\n")
    lines = []
    for idx, source in enumerate(raw):
        num = idx + 1
        # Tab used for indentation is an error.
        stripped_left = source.lstrip(" ")
        indent = len(source) - len(stripped_left)
        if stripped_left[:1] == "\t" or (source[:indent] != " " * indent):
            _err("tab used for indentation (YAML forbids tabs; use spaces)", num)
        body = _strip_comment(source).rstrip()
        if body.strip() == "":
            continue  # blank or comment-only line
        lines.append(_Line(indent, body, num))
    return lines, raw


# ---------------------------------------------------------------------------
# Block parser
# ---------------------------------------------------------------------------

class _Parser:
    def __init__(self, lines, raw):
        self.lines = lines
        self.raw = raw
        self.i = 0

    def _peek(self):
        return self.lines[self.i] if self.i < len(self.lines) else None

    def parse_document(self):
        if not self.lines:
            return None
        return self._parse_block(self.lines[0].indent)

    def _parse_block(self, indent):
        line = self._peek()
        if line is None or line.indent < indent:
            return None
        if line.content.lstrip()[:1] == "-" and _is_seq_marker(line.content):
            return self._parse_sequence(indent)
        return self._parse_mapping(indent)

    # -- mappings ----------------------------------------------------------

    def _parse_mapping(self, indent):
        out = {}
        while True:
            line = self._peek()
            if line is None or line.indent < indent:
                break
            if line.indent > indent:
                _err(f"unexpected indentation in mapping: {line.content.strip()!r}",
                     line.num)
            if line.content.lstrip()[:1] == "-" and _is_seq_marker(line.content):
                _err("sequence item '-' where a mapping key was expected",
                     line.num)
            key_text, rest = self._split_key(line)
            self.i += 1
            out[key_text] = self._value_after_key(rest, indent, line.num)
        return out

    def _split_key(self, line):
        """Split 'key: rest' honouring quotes inside the key."""
        content = line.content
        _reject_unsupported(content, line.num)
        in_s = in_d = False
        i, n = 0, len(content)
        while i < n:
            c = content[i]
            if in_s:
                if c == "'":
                    in_s = False
            elif in_d:
                if c == "\\":
                    i += 2
                    continue
                if c == '"':
                    in_d = False
            else:
                if c == "'":
                    in_s = True
                elif c == '"':
                    in_d = True
                elif c == ":" and (i + 1 == n or content[i + 1] in " \t"):
                    key_raw = content[:i].strip()
                    return self._key_string(key_raw, line.num), content[i + 1:]
            i += 1
        _err(f"expected 'key: value' mapping entry, got {content.strip()!r}",
             line.num)

    def _key_string(self, key_raw, num):
        if key_raw == "<<":
            _err("merge keys ('<<') are not supported", num)
        if key_raw[:1] == '"':
            end, val = _scan_double(key_raw, 0, num)
            return val
        if key_raw[:1] == "'":
            end, val = _scan_single(key_raw, 0, num)
            return val
        return key_raw

    def _value_after_key(self, rest, indent, num):
        stripped = rest.strip()
        # Block scalar: | or > (with optional chomp/indent indicators)
        if stripped and stripped[0] in "|>":
            return self._parse_block_scalar(stripped, indent, num)
        if stripped != "":
            return _parse_inline_value(stripped, num)
        # Value on following, more-indented lines.
        return self._parse_nested_value(indent)

    def _parse_nested_value(self, indent):
        line = self._peek()
        if line is None or line.indent < indent:
            return None  # empty value (e.g. `key:` with nothing under it)
        is_seq = line.content.lstrip()[:1] == "-" and _is_seq_marker(line.content)
        # A sequence may sit at the SAME indent as its parent key in YAML.
        if line.indent == indent:
            if is_seq:
                return self._parse_sequence(indent)
            return None  # a sibling mapping key, not this key's value
        if is_seq:
            return self._parse_sequence(line.indent)
        return self._parse_block(line.indent)

    # -- sequences ---------------------------------------------------------

    def _parse_sequence(self, indent):
        items = []
        while True:
            line = self._peek()
            if line is None or line.indent < indent:
                break
            if line.indent > indent:
                _err(f"unexpected indentation in sequence: {line.content.strip()!r}",
                     line.num)
            content = line.content
            if not (content.lstrip()[:1] == "-" and _is_seq_marker(content)):
                break  # dedent back to a mapping at this level
            items.append(self._parse_seq_item(line, indent))
        return items

    def _parse_seq_item(self, line, indent):
        content = line.content
        dash_col = line.indent  # '-' is the first non-space char
        after = content[dash_col + 1:]
        after_stripped = after.strip()
        # The column where the item's content begins (after "- ").
        item_indent = dash_col + 1 + (len(after) - len(after.lstrip(" ")))

        if after_stripped == "":
            # Item content is entirely on following lines.
            self.i += 1
            nxt = self._peek()
            if nxt is None or nxt.indent <= dash_col:
                return None
            return self._parse_block(nxt.indent)

        _reject_unsupported(after_stripped, line.num)

        # Block scalar as a sequence item: "- |" / "- >"
        if after_stripped[0] in "|>":
            self.i += 1
            return self._parse_block_scalar(after_stripped, dash_col, line.num)

        # Flow / quoted / plain scalar item on the same line...
        if after_stripped[0] in "[{\"'":
            self.i += 1
            return _parse_inline_value(after_stripped, line.num)

        # ...unless it's an inline mapping start ("- key: value"), which opens
        # a mapping whose first key sits at item_indent.
        if _looks_like_mapping_entry(after):
            return self._parse_inline_seq_mapping(line, item_indent)

        self.i += 1
        return _parse_inline_value(after_stripped, line.num)

    def _parse_inline_seq_mapping(self, line, item_indent):
        """Handle '- key: val' possibly followed by more keys of the same map.

        Rewrite the current line so its first key appears at item_indent, then
        let the mapping parser consume it and any sibling keys.
        """
        rewritten = " " * item_indent + line.content[item_indent:]
        self.lines[self.i] = _Line(item_indent, rewritten, line.num)
        return self._parse_mapping(item_indent)

    # -- block scalars -----------------------------------------------------

    def _parse_block_scalar(self, header, parent_indent, num):
        style = header[0]  # '|' or '>'
        indicators = header[1:].strip()
        chomp = "clip"
        explicit_indent = None
        for ch in indicators:
            if ch == "-":
                chomp = "strip"
            elif ch == "+":
                chomp = "keep"
            elif ch.isdigit():
                explicit_indent = int(ch)
            else:
                _err(f"unsupported block scalar indicator {ch!r} in {header!r}", num)

        # Collect the raw source lines belonging to the block (interior blanks
        # kept; trailing blanks reported separately for '+' chomping).
        block_lines, trailing_blanks = self._collect_block_raw(parent_indent, num)

        if not block_lines:
            return "\n" * trailing_blanks if chomp == "keep" else ""

        # Determine block indentation.
        if explicit_indent is not None:
            block_indent = parent_indent + explicit_indent
        else:
            block_indent = min(
                (len(l) - len(l.lstrip(" ")) for l in block_lines if l.strip()),
                default=parent_indent + 1,
            )

        stripped = []
        for l in block_lines:
            if l.strip() == "":
                stripped.append("")
            else:
                stripped.append(l[block_indent:] if len(l) >= block_indent else l.lstrip(" "))

        if style == "|":
            text = "\n".join(stripped)
        else:
            text = _fold(stripped)

        if chomp == "keep":
            # Keep every trailing newline: one to end the last content line,
            # plus one per trailing blank line.
            return text + "\n" + "\n" * trailing_blanks
        return _apply_chomp(text, chomp)

    def _collect_block_raw(self, parent_indent, header_num):
        """Return raw source lines that belong to a block scalar.

        The header line has already been consumed from `self.i`. We advance
        the logical cursor past all lines that are part of the block, and
        return the corresponding raw text (blank lines included).
        """
        # Find raw start: the line right after the header.
        raw_start = header_num  # 0-based index of the line after header (num is 1-based)
        collected = []
        raw_idx = raw_start
        last_taken = None
        while raw_idx < len(self.raw):
            source = self.raw[raw_idx]
            if source.strip() == "":
                collected.append(source)  # blank line, provisionally part of block
                raw_idx += 1
                continue
            indent = len(source) - len(source.lstrip(" "))
            if indent <= parent_indent:
                break
            collected.append(source)
            last_taken = len(collected)
            raw_idx += 1

        # Split trailing blank lines off the content; they are handled by
        # chomping (default 'clip'/'strip' drop them, '+' keeps them).
        if last_taken is None:
            content, trailing_blanks = [], 0
        else:
            content = collected[:last_taken]
            trailing_blanks = len(collected) - last_taken
            # A file ending in '\n' yields one artifact empty element from the
            # split; it is the line terminator, not a blank content line.
            if raw_idx == len(self.raw) and self.raw and self.raw[-1] == "":
                trailing_blanks = max(0, trailing_blanks - 1)

        # Advance the logical cursor past every logical line whose source
        # number falls inside the consumed raw range [raw_start, raw_idx).
        end_num = raw_idx  # 1-based exclusive bound == 0-based index reached
        while self.i < len(self.lines) and self.lines[self.i].num <= end_num:
            self.i += 1
        return content, trailing_blanks


def _fold(lines):
    """Fold a '>' block: join consecutive non-blank lines with a single space;
    a blank line becomes a newline (paragraph break)."""
    out = []
    prev_blank = True
    for l in lines:
        if l == "":
            out.append("\n")
            prev_blank = True
        else:
            if not prev_blank:
                out.append(" ")
            out.append(l)
            prev_blank = False
    return "".join(out)


def _apply_chomp(text, chomp):
    if chomp == "strip":
        return text.rstrip("\n")
    if chomp == "keep":
        return text if text.endswith("\n") else text + "\n"
    # clip: exactly one trailing newline (if there was content).
    return text.rstrip("\n") + ("\n" if text.strip("\n") != "" or text else "")


def _is_seq_marker(content):
    """True if a comment-stripped line is a sequence entry ('-' or '- x')."""
    s = content.lstrip()
    return s == "-" or s[:2] == "- "


def _looks_like_mapping_entry(text):
    """Heuristic: does `text` start a 'key: value' entry (outside quotes)?"""
    in_s = in_d = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if in_s:
            if c == "'":
                in_s = False
        elif in_d:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_d = False
        else:
            if c == "'":
                in_s = True
            elif c == '"':
                in_d = True
            elif c == ":" and (i + 1 == n or text[i + 1] in " \t"):
                return True
            elif c in "[{":
                return False
        i += 1
    return False


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def _strip_document_markers(text):
    """Drop a leading '---' and trailing '...'; error on a second '---'."""
    lines = text.split("\n")
    doc_starts = []
    for idx, line in enumerate(lines):
        s = line.strip()
        if s == "---" or s.startswith("--- "):
            doc_starts.append(idx)
    if len(doc_starts) > 1:
        _err("multiple documents ('---') are not supported; load one at a time",
             doc_starts[1] + 1)
    # Blank out a single leading '---' (preserve line numbering) ...
    out = list(lines)
    if doc_starts:
        idx = doc_starts[0]
        # A '---' preceded by real content starts a *second* document.
        for prior in lines[:idx]:
            if prior.strip() and not prior.lstrip().startswith("#"):
                _err("multiple documents ('---') are not supported; "
                     "load one at a time", idx + 1)
        out[idx] = ""  # keep line count stable for error line numbers
    # Blank out a trailing '...' end-of-document marker.
    for idx, line in enumerate(out):
        if line.strip() == "...":
            out[idx] = ""
    return "\n".join(out)


def load(text):
    """Parse a single YAML document to a Python object.

    Raises YamlError (with an approximate line number) on anything outside the
    supported subset. Never imports yaml; never executes anything.
    """
    if not isinstance(text, str):
        _err("load() expects a string")
    prepared = _strip_document_markers(text)
    lines, raw = _prepare_lines(prepared)
    if not lines:
        return None
    parser = _Parser(lines, raw)
    result = parser.parse_document()
    leftover = parser._peek()
    if leftover is not None:
        _err(f"could not parse line: {leftover.content.strip()!r}", leftover.num)
    return result


def load_file(path):
    """Read and parse a YAML file."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return load(fh.read())
    except OSError as exc:
        _err(f"cannot read {path}: {exc}")


def dig(obj, *path):
    """Return the value at a path of string keys / int indices, else None.

    dig(cfg, "jobs", "build", "steps", 0, "run")
    """
    cur = obj
    for seg in path:
        if isinstance(seg, int) and isinstance(cur, list):
            if -len(cur) <= seg < len(cur):
                cur = cur[seg]
            else:
                return None
        elif isinstance(cur, dict) and seg in cur:
            cur = cur[seg]
        else:
            return None
    return cur


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _dig_dotted(obj, dotted):
    """dig using a dotted path; numeric segments become list indices."""
    path = []
    for seg in dotted.split("."):
        if re.fullmatch(r"-?[0-9]+", seg):
            path.append(int(seg))
        else:
            path.append(seg)
    return dig(obj, *path), path


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    get_path = None
    if "--get" in argv:
        gi = argv.index("--get")
        if gi + 1 >= len(argv):
            print("yamlmini: --get requires a dotted path argument", file=sys.stderr)
            return 2
        get_path = argv[gi + 1]
        argv = argv[:gi] + argv[gi + 2:]
    if len(argv) != 1:
        print("usage: yamlmini.py <file.yml> [--get a.b.0.c]", file=sys.stderr)
        return 2
    try:
        data = load_file(argv[0])
    except YamlError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    if get_path is not None:
        value, path = _dig_dotted(data, get_path)
        if value is None and not _path_exists(data, path):
            print(f"yamlmini: no value at path {get_path!r}", file=sys.stderr)
            return 3
        if isinstance(value, (dict, list)):
            print(json.dumps(value, indent=2, sort_keys=False))
        elif value is None:
            print("null")
        elif isinstance(value, bool):
            print("true" if value else "false")
        else:
            print(value)
        return 0
    print(json.dumps(data, indent=2, sort_keys=False, default=str))
    return 0


def _path_exists(obj, path):
    """True if `path` resolves to a present slot (even if its value is None)."""
    cur = obj
    for seg in path:
        if isinstance(seg, int) and isinstance(cur, list):
            if -len(cur) <= seg < len(cur):
                cur = cur[seg]
            else:
                return False
        elif isinstance(cur, dict) and seg in cur:
            cur = cur[seg]
        else:
            return False
    return True


if __name__ == "__main__":
    sys.exit(main())
