#!/usr/bin/env python3
"""kqlmini -- a small, deterministic, offline evaluator for a KQL subset.

Grades learner-written KQL queries against JSON fixture tables. Pure
stdlib, no network, no wall clock: `ago()`/`now()` read the fixture's
"@now" key, so results are fully reproducible.

Supported grammar
=================

query        := TableName ( '|' operator )*

operators:
    where <expr>
    project <col | Name = expr> [, ...]
    project-away <col> [, ...]
    extend Name = <expr> [, ...]
    summarize [Name =] <agg> [, ...] [by [Name =] <col | bin(col, size)> [, ...]]
    count                               -- one row, column "Count"
    top <N> by <expr> [asc | desc]      -- default desc, nulls last
    sort by <expr> [asc | desc] [, ...] -- alias: order by; default desc, nulls last
    take <N>    /    limit <N>
    distinct <col [, ...] | *>

aggregations:
    count(), countif(expr), dcount(col), sum(expr), avg(expr), min(expr), max(expr)
    Default result-column names: count() -> count_ ; countif(...) -> countif_ ;
    an aggregate over a bare column C -> agg_C (e.g. avg_CounterValue); any
    other argument expression -> agg_ (use `Name = agg(...)` to pick a name).
    A `by` expression is named after its column (bin(C, size) -> C); anything
    else must be aliased `Name = expr`.

expressions:
    comparison    == != < <= > >=       (== is case-SENSITIVE for strings)
    case-insens   =~ !~                 (case-insensitive string equality)
    arithmetic    + - * /               ('/' is real division)
    boolean       and  or  not, parentheses
    literals      123, 4.5, 'str' or "str", true/false,
                  datetime(2026-07-03T12:00:00)  (ISO-8601, quoted or bare),
                  timespans: 30s 5m 1h 2d 250ms
    string ops    contains !contains startswith endswith  (case-insensitive,
                  as in real KQL)
                  has            (case-insensitive whole-token match on
                                  non-alphanumeric boundaries)
                  in (...)  !in (...)   (case-sensitive membership)
    functions     strcat(...), strlen(s), tolower(s), toupper(s), tostring(v),
                  toint(v), todouble(v), bin(value, roundTo), iff(cond, a, b),
                  isempty(v), isnotempty(v), ago(timespan), now()

time:
    ago()/now() never read the wall clock: the fixture must supply an
    "@now" key (ISO-8601 string). Using them without "@now" is an error.

nulls:
    Missing columns evaluate to null; any comparison or string operator
    against null is false; arithmetic with null is null; aggregates skip
    nulls (count() counts rows); sorting puts nulls last.

fixtures:
    A JSON object mapping TableName -> list of row objects. On load,
    string values that look like ISO-8601 timestamps ("YYYY-MM-DD[T ]hh:mm"
    with optional seconds/offset) are converted to datetime. The optional
    "@now" key (ISO string) injects the clock for ago()/now().

CLI:
    python3 kqlmini.py <fixture.json> <query.kql>        -- JSON lines
    python3 kqlmini.py --table <fixture.json> <query.kql> -- aligned table
    Exit 0 on success, 2 on parse/eval/IO failure (message on stderr).
"""

from __future__ import annotations

import functools
import json
import math
import re
import sys
from datetime import datetime, timedelta

__all__ = ["load_fixture", "run_query", "rows_equal", "main", "KqlError"]


class KqlError(Exception):
    """Any kqlmini parse or evaluation failure."""


def _err(msg):
    raise KqlError("kqlmini: " + msg)


# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------

_TS_SECONDS = {"d": 86400.0, "h": 3600.0, "m": 60.0, "s": 1.0, "ms": 0.001}
_TWO_CHAR_OPS = ("==", "!=", "<=", ">=", "=~", "!~")
_ONE_CHAR_OPS = "()+-*/,|<>=!"
_NUM_RE = re.compile(r"\d+(?:\.\d+)?")
_UNIT_RE = re.compile(r"(ms|[dhms])(?![A-Za-z0-9_])")
_IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_ISO_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$"
)

_EOF = ("eof", None, -1)


def _parse_datetime(text):
    s = text.strip().strip("'\"").strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(s)
    except ValueError:
        _err(f"invalid datetime literal {text.strip()!r} (expected ISO-8601)")


def _scan_string(text, i):
    quote = text[i]
    out = []
    i += 1
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            out.append({"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"'}.get(nxt, nxt))
            i += 2
            continue
        if c == quote:
            return i + 1, "".join(out)
        out.append(c)
        i += 1
    _err("unterminated string literal")


def tokenize(text):
    """Return a list of (kind, value, pos) tokens ending with an 'eof' token."""
    toks = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r\n":
            i += 1
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
            continue
        if c in "'\"":
            start = i
            i, s = _scan_string(text, i)
            toks.append(("str", s, start))
            continue
        if c.isdigit():
            m = _NUM_RE.match(text, i)
            num = m.group(0)
            j = m.end()
            m2 = _UNIT_RE.match(text, j)
            if m2:  # timespan literal like 5m / 1h / 250ms
                span = timedelta(seconds=float(num) * _TS_SECONDS[m2.group(1)])
                toks.append(("timespan", span, i))
                i = m2.end()
            else:
                toks.append(("num", float(num) if "." in num else int(num), i))
                i = j
            continue
        if c.isalpha() or c == "_":
            m = _IDENT_RE.match(text, i)
            word = m.group(0)
            j = m.end()
            if word == "datetime" and j < n and text[j] == "(":
                k = text.find(")", j)
                if k < 0:
                    _err("unterminated datetime(...) literal")
                toks.append(("dt", _parse_datetime(text[j + 1:k]), i))
                i = k + 1
            else:
                toks.append(("ident", word, i))
                i = j
            continue
        if text[i:i + 2] in _TWO_CHAR_OPS:
            toks.append(("op", text[i:i + 2], i))
            i += 2
            continue
        if c in _ONE_CHAR_OPS:
            toks.append(("op", c, i))
            i += 1
            continue
        _err(f"unexpected character {c!r} at position {i}")
    toks.append(_EOF)
    return toks


# ---------------------------------------------------------------------------
# Parser (recursive descent)
# ---------------------------------------------------------------------------

_OPERATORS = ("where", "project", "project-away", "extend", "summarize",
              "count", "top", "sort", "order", "take", "limit", "distinct")
_AGG_FUNCS = ("count", "countif", "dcount", "sum", "avg", "min", "max")
# name -> (min arity, max arity or None for unbounded)
_SCALAR_FUNCS = {
    "strcat": (1, None), "strlen": (1, 1), "tolower": (1, 1), "toupper": (1, 1),
    "tostring": (1, 1), "toint": (1, 1), "todouble": (1, 1), "bin": (2, 2),
    "iff": (3, 3), "isempty": (1, 1), "isnotempty": (1, 1),
    "ago": (1, 1), "now": (0, 0),
}
_CMP_OPS = {"==", "!=", "<", "<=", ">", ">=", "=~", "!~"}
_STR_OPS = {"contains", "startswith", "endswith", "has"}


class _Parser:
    def __init__(self, tokens):
        self.toks = tokens
        self.i = 0

    def peek(self, k=0):
        j = self.i + k
        return self.toks[j] if j < len(self.toks) else _EOF

    def next(self):
        t = self.toks[self.i]
        if t[0] != "eof":
            self.i += 1
        return t

    def at(self, kind, value=None):
        t = self.peek()
        return t[0] == kind and (value is None or t[1] == value)

    def accept(self, kind, value=None):
        if self.at(kind, value):
            return self.next()
        return None

    @staticmethod
    def _show(tok):
        return "end of query" if tok[0] == "eof" else repr(tok[1])

    def expect_op(self, op):
        t = self.next()
        if t[0] != "op" or t[1] != op:
            _err(f"expected '{op}', got {self._show(t)}")

    def expect_ident(self, word=None):
        t = self.next()
        if t[0] != "ident" or (word is not None and t[1] != word):
            _err(f"expected {word or 'a name'!r}, got {self._show(t)}")
        return t[1]

    # -- pipeline ----------------------------------------------------------

    def parse_query(self):
        t = self.next()
        if t[0] != "ident":
            _err(f"query must start with a table name, got {self._show(t)}")
        table = t[1]
        ops = []
        while not self.at("eof"):
            if not self.accept("op", "|"):
                _err(f"expected '|' or end of query, got {self._show(self.peek())}")
            ops.append(self.parse_operator())
        return table, ops

    def _operator_name(self):
        t = self.next()
        if t[0] != "ident":
            _err(f"expected an operator after '|', got {self._show(t)}")
        name, end = t[1], t[2] + len(t[1])
        # join hyphenated operator names written without spaces: project-away
        while (self.peek()[0] == "op" and self.peek()[1] == "-"
               and self.peek()[2] == end
               and self.peek(1)[0] == "ident" and self.peek(1)[2] == end + 1):
            self.next()
            part = self.next()
            name += "-" + part[1]
            end = part[2] + len(part[1])
        return name

    def parse_operator(self):
        name = self._operator_name()
        if name == "where":
            return ("where", self.parse_expr())
        if name == "project":
            return ("project", self._parse_named_list("project"))
        if name == "project-away":
            return ("project-away", self._parse_column_list("project-away"))
        if name == "extend":
            return ("extend", self._parse_extend_list())
        if name == "summarize":
            return self._parse_summarize()
        if name == "count":
            return ("count",)
        if name == "top":
            return self._parse_top()
        if name in ("sort", "order"):
            self.expect_ident("by")
            return ("sort", self._parse_sort_keys())
        if name in ("take", "limit"):
            return ("take", self._parse_count(name))
        if name == "distinct":
            return self._parse_distinct()
        _err(f"unsupported operator '{name}' (supported: {', '.join(_OPERATORS)})")

    def _parse_count(self, opname):
        t = self.next()
        if t[0] != "num" or not isinstance(t[1], int):
            _err(f"{opname} expects an integer row count, got {self._show(t)}")
        return t[1]

    def _maybe_alias(self):
        """Consume `Name =` if present, returning the name or None."""
        if (self.at("ident") and self.peek(1)[0] == "op" and self.peek(1)[1] == "="):
            name = self.next()[1]
            self.next()  # '='
            return name
        return None

    def _parse_named_list(self, opname):
        items = []
        while True:
            alias = self._maybe_alias()
            expr = self.parse_expr()
            if alias is None:
                if expr[0] != "col":
                    _err(f"{opname} expression needs an alias (Name = expr)")
                alias = expr[1]
            items.append((alias, expr))
            if not self.accept("op", ","):
                return items

    def _parse_column_list(self, opname):
        cols = [self.expect_ident()]
        while self.accept("op", ","):
            cols.append(self.expect_ident())
        return cols

    def _parse_extend_list(self):
        items = []
        while True:
            name = self.expect_ident()
            self.expect_op("=")
            items.append((name, self.parse_expr()))
            if not self.accept("op", ","):
                return items

    def _parse_summarize(self):
        aggs = [self._parse_agg_item()]
        while self.accept("op", ","):
            aggs.append(self._parse_agg_item())
        bys = []
        if self.accept("ident", "by"):
            bys.append(self._parse_by_item())
            while self.accept("op", ","):
                bys.append(self._parse_by_item())
        return ("summarize", aggs, bys)

    def _parse_agg_item(self):
        alias = self._maybe_alias()
        fn = self.expect_ident()
        if fn not in _AGG_FUNCS:
            _err(f"unsupported aggregation '{fn}' (supported: {', '.join(_AGG_FUNCS)})")
        self.expect_op("(")
        arg = None
        if not self.at("op", ")"):
            arg = self.parse_expr()
        self.expect_op(")")
        if fn == "count" and arg is not None:
            _err("count() takes no arguments (did you mean countif or dcount?)")
        if fn != "count" and arg is None:
            _err(f"{fn}() requires an argument")
        if alias is None:
            if fn == "count":
                alias = "count_"
            elif arg[0] == "col":
                alias = f"{fn}_{arg[1]}"
            else:
                alias = f"{fn}_"
        return (alias, fn, arg)

    def _parse_by_item(self):
        alias = self._maybe_alias()
        expr = self.parse_expr()
        if alias is None:
            if expr[0] == "col":
                alias = expr[1]
            elif expr[0] == "call" and expr[1] == "bin" and expr[2][0][0] == "col":
                alias = expr[2][0][1]
            else:
                _err("summarize by-expression needs an alias (Name = expr)")
        return (alias, expr)

    def _parse_top(self):
        n = self._parse_count("top")
        self.expect_ident("by")
        expr = self.parse_expr()
        ascending = self._parse_direction()
        return ("top", n, expr, ascending)

    def _parse_direction(self):
        if self.accept("ident", "asc"):
            return True
        if self.accept("ident", "desc"):
            return False
        return False  # KQL default: descending

    def _parse_sort_keys(self):
        keys = [(self.parse_expr(), None)]
        keys[0] = (keys[0][0], self._parse_direction())
        while self.accept("op", ","):
            expr = self.parse_expr()
            keys.append((expr, self._parse_direction()))
        return keys

    def _parse_distinct(self):
        if self.accept("op", "*"):
            return ("distinct", None)
        return ("distinct", self._parse_column_list("distinct"))

    # -- expressions -------------------------------------------------------

    def parse_expr(self):
        return self._parse_or()

    def _parse_or(self):
        left = self._parse_and()
        while self.accept("ident", "or"):
            left = ("or", left, self._parse_and())
        return left

    def _parse_and(self):
        left = self._parse_not()
        while self.accept("ident", "and"):
            left = ("and", left, self._parse_not())
        return left

    def _parse_not(self):
        if self.accept("ident", "not"):
            return ("not", self._parse_not())
        return self._parse_comparison()

    def _parse_comparison(self):
        left = self._parse_additive()
        t = self.peek()
        if t[0] == "op" and t[1] in _CMP_OPS:
            self.next()
            return ("cmp", t[1], left, self._parse_additive())
        if t[0] == "ident" and t[1] in _STR_OPS:
            self.next()
            return ("strop", t[1], False, left, self._parse_additive())
        if t[0] == "ident" and t[1] == "in":
            self.next()
            return self._parse_in(left, negated=False)
        if t[0] == "op" and t[1] == "!":
            nxt = self.peek(1)
            if nxt[0] == "ident" and nxt[1] in ("contains", "in"):
                self.next()
                self.next()
                if nxt[1] == "in":
                    return self._parse_in(left, negated=True)
                return ("strop", "contains", True, left, self._parse_additive())
            _err("unexpected '!' (did you mean !=, !~, !contains or !in?)")
        return left

    def _parse_in(self, left, negated):
        self.expect_op("(")
        items = [self.parse_expr()]
        while self.accept("op", ","):
            items.append(self.parse_expr())
        self.expect_op(")")
        return ("in", negated, left, items)

    def _parse_additive(self):
        left = self._parse_multiplicative()
        while self.at("op", "+") or self.at("op", "-"):
            op = self.next()[1]
            left = ("arith", op, left, self._parse_multiplicative())
        return left

    def _parse_multiplicative(self):
        left = self._parse_unary()
        while self.at("op", "*") or self.at("op", "/"):
            op = self.next()[1]
            left = ("arith", op, left, self._parse_unary())
        return left

    def _parse_unary(self):
        if self.accept("op", "-"):
            return ("neg", self._parse_unary())
        return self._parse_primary()

    def _parse_primary(self):
        t = self.next()
        if t[0] in ("num", "str", "timespan", "dt"):
            return ("lit", t[1])
        if t[0] == "op" and t[1] == "(":
            expr = self.parse_expr()
            self.expect_op(")")
            return expr
        if t[0] == "ident":
            word = t[1]
            if word == "true":
                return ("lit", True)
            if word == "false":
                return ("lit", False)
            if self.at("op", "("):
                self.next()
                args = []
                if not self.at("op", ")"):
                    args.append(self.parse_expr())
                    while self.accept("op", ","):
                        args.append(self.parse_expr())
                self.expect_op(")")
                if word in _AGG_FUNCS:
                    _err(f"aggregation '{word}()' is only allowed inside summarize")
                if word not in _SCALAR_FUNCS:
                    _err(f"unsupported function '{word}()' "
                         f"(supported: {', '.join(sorted(_SCALAR_FUNCS))})")
                lo, hi = _SCALAR_FUNCS[word]
                if len(args) < lo or (hi is not None and len(args) > hi):
                    want = str(lo) if lo == hi else f"{lo}..{hi if hi is not None else 'more'}"
                    _err(f"{word}() takes {want} argument(s), got {len(args)}")
                return ("call", word, args)
            return ("col", word)
        _err(f"unexpected {self._show(t)} in expression")


# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------

def _truthy(v):
    return bool(v)  # None -> False, like KQL's null-is-not-true


def _eq(l, r):
    if isinstance(l, bool) != isinstance(r, bool):
        return False  # true != 1
    return l == r


def _order_cmp(a, b):
    try:
        if a < b:
            return -1
        if b < a:
            return 1
        return 0
    except TypeError:
        return 0


def _to_str(v):
    if v is None:
        return ""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, datetime):
        return v.isoformat()
    return str(v)


def _bin(value, size):
    if value is None or size is None:
        return None
    if isinstance(value, datetime) and isinstance(size, timedelta):
        base = datetime.min.replace(tzinfo=value.tzinfo)
        return base + ((value - base) // size) * size
    if isinstance(value, timedelta) and isinstance(size, timedelta):
        return (value // size) * size
    if isinstance(value, (int, float)) and isinstance(size, (int, float)) \
            and not isinstance(value, bool) and not isinstance(size, bool):
        return math.floor(value / size) * size
    _err("bin(): expected (number, number) or (datetime, timespan)")


def _call(name, args, row, ctx):
    if name == "iff":
        cond = _truthy(_eval(args[0], row, ctx))
        return _eval(args[1] if cond else args[2], row, ctx)
    vals = [_eval(a, row, ctx) for a in args]
    if name == "strcat":
        return "".join(_to_str(v) for v in vals)
    if name == "strlen":
        return len(_to_str(vals[0]))
    if name == "tolower":
        return None if vals[0] is None else _to_str(vals[0]).lower()
    if name == "toupper":
        return None if vals[0] is None else _to_str(vals[0]).upper()
    if name == "tostring":
        return _to_str(vals[0])
    if name == "toint":
        try:
            return int(float(vals[0]))
        except (TypeError, ValueError):
            return None
    if name == "todouble":
        try:
            return float(vals[0])
        except (TypeError, ValueError):
            return None
    if name == "bin":
        return _bin(vals[0], vals[1])
    if name == "isempty":
        return vals[0] is None or vals[0] == ""
    if name == "isnotempty":
        return not (vals[0] is None or vals[0] == "")
    if name in ("ago", "now"):
        if ctx.get("now") is None:
            _err(f"{name}() requires an '@now' key in the fixture "
                 "(deterministic time; wall clock is never used)")
        return ctx["now"] - vals[0] if name == "ago" else ctx["now"]
    raise AssertionError(f"unhandled function {name}")  # pragma: no cover


def _compare(op, l, r):
    if l is None or r is None:
        return False
    if op in ("==", "!="):
        return _eq(l, r) if op == "==" else not _eq(l, r)
    if op in ("=~", "!~"):
        if isinstance(l, str) and isinstance(r, str):
            eq = l.lower() == r.lower()
        else:
            eq = _eq(l, r)
        return eq if op == "=~" else not eq
    c = None
    try:
        if l < r:
            c = -1
        elif r < l:
            c = 1
        else:
            c = 0
    except TypeError:
        return False  # incomparable types: false, like null
    return {"<": c < 0, "<=": c <= 0, ">": c > 0, ">=": c >= 0}[op]


def _str_op(name, l, r):
    if l is None or r is None:
        return False
    hay, needle = _to_str(l).lower(), _to_str(r).lower()
    if name == "contains":
        return needle in hay
    if name == "startswith":
        return hay.startswith(needle)
    if name == "endswith":
        return hay.endswith(needle)
    if name == "has":
        return needle in re.split(r"[^a-z0-9]+", hay)
    raise AssertionError(name)  # pragma: no cover


def _eval(node, row, ctx):
    kind = node[0]
    if kind == "lit":
        return node[1]
    if kind == "col":
        return row.get(node[1])
    if kind == "and":
        return _truthy(_eval(node[1], row, ctx)) and _truthy(_eval(node[2], row, ctx))
    if kind == "or":
        return _truthy(_eval(node[1], row, ctx)) or _truthy(_eval(node[2], row, ctx))
    if kind == "not":
        return not _truthy(_eval(node[1], row, ctx))
    if kind == "cmp":
        return _compare(node[1], _eval(node[2], row, ctx), _eval(node[3], row, ctx))
    if kind == "strop":
        l, r = _eval(node[3], row, ctx), _eval(node[4], row, ctx)
        if l is None or r is None:
            return False  # null: false even when negated (like KQL)
        result = _str_op(node[1], l, r)
        return (not result) if node[2] else result
    if kind == "in":
        _, negated, left, items = node
        lv = _eval(left, row, ctx)
        if lv is None:
            return False
        member = any(_eq(lv, _eval(item, row, ctx)) for item in items)
        return (not member) if negated else member
    if kind == "arith":
        l, r = _eval(node[2], row, ctx), _eval(node[3], row, ctx)
        if l is None or r is None:
            return None
        try:
            if node[1] == "+":
                return l + r
            if node[1] == "-":
                return l - r
            if node[1] == "*":
                return l * r
            return l / r
        except (TypeError, ZeroDivisionError):
            return None
    if kind == "neg":
        v = _eval(node[1], row, ctx)
        try:
            return None if v is None else -v
        except TypeError:
            return None
    if kind == "call":
        return _call(node[1], node[2], row, ctx)
    raise AssertionError(f"unhandled node {kind}")  # pragma: no cover


# ---------------------------------------------------------------------------
# Operators
# ---------------------------------------------------------------------------

def _sort_rows(rows, keys, ctx):
    """Stable multi-key sort; per-key asc flag; nulls always last."""
    cache = [[_eval(expr, r, ctx) for expr, _ in keys] for r in rows]

    def cmp(ia, ib):
        for k, (_, ascending) in enumerate(keys):
            va, vb = cache[ia][k], cache[ib][k]
            if va is None and vb is None:
                continue
            if va is None:
                return 1
            if vb is None:
                return -1
            c = _order_cmp(va, vb)
            if c:
                return c if ascending else -c
        return ia - ib  # stable: preserve input order on ties

    order = sorted(range(len(rows)), key=functools.cmp_to_key(cmp))
    return [rows[i] for i in order]


def _agg_value(fn, arg, rows, ctx):
    if fn == "count":
        return len(rows)
    if fn == "countif":
        return sum(1 for r in rows if _truthy(_eval(arg, r, ctx)))
    vals = [v for v in (_eval(arg, r, ctx) for r in rows) if v is not None]
    if fn == "dcount":
        return len(set(vals))
    if not vals:
        return None
    try:
        if fn == "sum":
            return sum(vals)
        if fn == "avg":
            return sum(vals) / len(vals)
        if fn == "min":
            return min(vals)
        return max(vals)
    except TypeError:
        _err(f"{fn}(): values are not all numeric/comparable")


def _apply_summarize(aggs, bys, rows, ctx):
    groups, order = {}, []
    for r in rows:
        key = tuple(_eval(expr, r, ctx) for _, expr in bys)
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append(r)
    if not bys and not order:  # summarize over empty input still yields a row
        groups[()] = []
        order.append(())
    out = []
    for key in order:
        row = {name: value for (name, _), value in zip(bys, key)}
        for name, fn, arg in aggs:
            row[name] = _agg_value(fn, arg, groups[key], ctx)
        out.append(row)
    return out


def _apply_distinct(cols, rows):
    if cols is None:  # distinct *
        cols = []
        for r in rows:
            for k in r:
                if k not in cols:
                    cols.append(k)
    seen, out = set(), []
    for r in rows:
        key = tuple(r.get(c) for c in cols)
        if key not in seen:
            seen.add(key)
            out.append({c: r.get(c) for c in cols})
    return out


def _apply_op(op, rows, ctx):
    kind = op[0]
    if kind == "where":
        return [r for r in rows if _truthy(_eval(op[1], r, ctx))]
    if kind == "project":
        return [{name: _eval(expr, r, ctx) for name, expr in op[1]} for r in rows]
    if kind == "project-away":
        away = set(op[1])
        return [{k: v for k, v in r.items() if k not in away} for r in rows]
    if kind == "extend":
        out = []
        for r in rows:
            r = dict(r)
            for name, expr in op[1]:
                r[name] = _eval(expr, r, ctx)
            out.append(r)
        return out
    if kind == "summarize":
        return _apply_summarize(op[1], op[2], rows, ctx)
    if kind == "count":
        return [{"Count": len(rows)}]
    if kind == "top":
        return _sort_rows(rows, [(op[2], op[3])], ctx)[:op[1]]
    if kind == "sort":
        return _sort_rows(rows, op[1], ctx)
    if kind == "take":
        return rows[:op[1]]
    if kind == "distinct":
        return _apply_distinct(op[1], rows)
    raise AssertionError(f"unhandled operator {kind}")  # pragma: no cover


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def load_fixture(path):
    """Load a JSON fixture: {"TableName": [row, ...], ..., "@now": "ISO"}.

    String cell values that look like ISO-8601 timestamps are converted
    to datetime objects so time comparisons and bin() work naturally.
    """
    with open(path, "r", encoding="utf-8") as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError as exc:
            _err(f"fixture {path}: invalid JSON ({exc})")
    if not isinstance(data, dict):
        _err(f"fixture {path}: expected a JSON object mapping table names to row lists")
    out = {}
    for name, rows in data.items():
        if name == "@now":
            if not isinstance(rows, str):
                _err('fixture "@now" must be an ISO-8601 string')
            out[name] = rows
            continue
        if not isinstance(rows, list) or not all(isinstance(r, dict) for r in rows):
            _err(f"fixture table {name!r} must be a list of row objects")
        out[name] = [
            {k: (_parse_datetime(v) if isinstance(v, str) and _ISO_RE.match(v) else v)
             for k, v in row.items()}
            for row in rows
        ]
    return out


def run_query(query_text, tables):
    """Evaluate a KQL query against fixture tables; returns a list of row dicts."""
    table, ops = _Parser(tokenize(query_text)).parse_query()
    now = tables.get("@now")
    if isinstance(now, str):
        now = _parse_datetime(now)
    ctx = {"now": now}
    if table.startswith("@") or table not in tables:
        names = sorted(n for n in tables if not n.startswith("@"))
        _err(f"unknown table '{table}' (fixture tables: {', '.join(names) or 'none'})")
    rows = [dict(r) for r in tables[table]]
    for op in ops:
        rows = _apply_op(op, rows, ctx)
    return rows


def _val_eq(a, b):
    both_num = (isinstance(a, (int, float)) and not isinstance(a, bool)
                and isinstance(b, (int, float)) and not isinstance(b, bool))
    if both_num:
        return math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-9)
    return a == b


def _row_eq(a, b):
    return a.keys() == b.keys() and all(_val_eq(a[k], b[k]) for k in a)


def rows_equal(a, b, ordered=False):
    """Compare two lists of row dicts. Floats match within 1e-9 (rel+abs).

    ordered=False (default) compares as multisets; ordered=True pairwise.
    """
    if len(a) != len(b):
        return False
    if ordered:
        return all(_row_eq(x, y) for x, y in zip(a, b))
    unmatched = list(b)
    for x in a:
        for i, y in enumerate(unmatched):
            if _row_eq(x, y):
                del unmatched[i]
                break
        else:
            return False
    return True


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _cell(v):
    if v is None:
        return ""
    return _to_str(v)


def _print_table(rows, out):
    cols = []
    for r in rows:
        for k in r:
            if k not in cols:
                cols.append(k)
    if not cols:
        print("(no rows)", file=out)
        return
    grid = [[_cell(r.get(c)) for c in cols] for r in rows]
    widths = [max(len(c), *(len(row[i]) for row in grid)) if grid else len(c)
              for i, c in enumerate(cols)]
    print("  ".join(c.ljust(w) for c, w in zip(cols, widths)).rstrip(), file=out)
    print("  ".join("-" * w for w in widths), file=out)
    for row in grid:
        print("  ".join(v.ljust(w) for v, w in zip(row, widths)).rstrip(), file=out)


def _jsonable(row):
    return {k: (_to_str(v) if isinstance(v, (datetime, timedelta)) else v)
            for k, v in row.items()}


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    table_mode = "--table" in argv
    args = [a for a in argv if a != "--table"]
    if len(args) != 2:
        print("usage: kqlmini.py [--table] <fixture.json> <query.kql>", file=sys.stderr)
        return 2
    try:
        tables = load_fixture(args[0])
        with open(args[1], "r", encoding="utf-8") as fh:
            query = fh.read()
        rows = run_query(query, tables)
    except KqlError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    except OSError as exc:
        print(f"kqlmini: {exc}", file=sys.stderr)
        return 2
    if table_mode:
        _print_table(rows, sys.stdout)
    else:
        for r in rows:
            print(json.dumps(_jsonable(r)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
