#!/usr/bin/env python3
"""Unit tests for kqlmini (stdlib unittest only).

Run either way:
    python3 -m unittest tools.test_kqlmini
    python3 tools/test_kqlmini.py
"""

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kqlmini
from kqlmini import KqlError, load_fixture, main, rows_equal, run_query

DT = datetime.fromisoformat
NOW = "2026-07-03T12:00:00"


def perf_tables():
    return {
        "@now": NOW,
        "Perf": [
            {"Computer": "web-01", "CounterName": "CPU", "CounterValue": 80.0,
             "TimeGenerated": DT("2026-07-03T11:10:00")},
            {"Computer": "web-01", "CounterName": "CPU", "CounterValue": 90.0,
             "TimeGenerated": DT("2026-07-03T11:40:00")},
            {"Computer": "web-02", "CounterName": "CPU", "CounterValue": 40.0,
             "TimeGenerated": DT("2026-07-03T11:50:00")},
            {"Computer": "web-02", "CounterName": "Memory", "CounterValue": 55.0,
             "TimeGenerated": DT("2026-07-03T09:00:00")},
            {"Computer": "db-01", "CounterName": "CPU", "CounterValue": None,
             "TimeGenerated": DT("2026-07-03T11:55:00")},
        ],
    }


def q(query, tables=None):
    return run_query(query, perf_tables() if tables is None else tables)


class WhereProjectTests(unittest.TestCase):
    def test_where_and_project(self):
        rows = q("Perf | where CounterValue > 50 | project Computer, CounterValue")
        self.assertEqual(rows, [
            {"Computer": "web-01", "CounterValue": 80.0},
            {"Computer": "web-01", "CounterValue": 90.0},
            {"Computer": "web-02", "CounterValue": 55.0},
        ])
        self.assertEqual(list(rows[0].keys()), ["Computer", "CounterValue"])

    def test_where_boolean_logic_and_parens(self):
        rows = q("Perf | where (CounterName == 'CPU' and CounterValue >= 80) "
                 "or Computer == 'db-01'")
        self.assertEqual([r["Computer"] for r in rows], ["web-01", "web-01", "db-01"])
        rows = q("Perf | where not (CounterName == 'CPU')")
        self.assertEqual([r["CounterName"] for r in rows], ["Memory"])

    def test_project_alias_and_arithmetic(self):
        rows = q("Perf | where Computer == 'web-01' "
                 "| project Pct = CounterValue / 100, Twice = CounterValue * 2, "
                 "Delta = CounterValue + 1 - 1")
        self.assertEqual(rows[0], {"Pct": 0.8, "Twice": 160.0, "Delta": 80.0})

    def test_project_expression_requires_alias(self):
        with self.assertRaises(KqlError) as cm:
            q("Perf | project CounterValue * 2")
        self.assertIn("alias", str(cm.exception))

    def test_project_away(self):
        rows = q("Perf | take 1 | project-away TimeGenerated, CounterName")
        self.assertEqual(set(rows[0]), {"Computer", "CounterValue"})

    def test_extend(self):
        rows = q("Perf | take 1 | extend Label = strcat(Computer, ':', CounterName), "
                 "High = CounterValue > 50")
        self.assertEqual(rows[0]["Label"], "web-01:CPU")
        self.assertIs(rows[0]["High"], True)
        # extend can reference a column created earlier in the same clause
        rows = q("Perf | take 1 | extend A = 2, B = A * 3")
        self.assertEqual(rows[0]["B"], 6)


class SummarizeTests(unittest.TestCase):
    def test_default_agg_names(self):
        rows = q("Perf | summarize count(), countif(CounterValue > 50), "
                 "dcount(Computer), sum(CounterValue), avg(CounterValue), "
                 "min(CounterValue), max(CounterValue)")
        self.assertEqual(len(rows), 1)
        r = rows[0]
        self.assertEqual(r["count_"], 5)          # count() counts null rows too
        self.assertEqual(r["countif_"], 3)
        self.assertEqual(r["dcount_Computer"], 3)
        self.assertEqual(r["sum_CounterValue"], 265.0)   # nulls skipped
        self.assertAlmostEqual(r["avg_CounterValue"], 265.0 / 4)
        self.assertEqual(r["min_CounterValue"], 40.0)
        self.assertEqual(r["max_CounterValue"], 90.0)

    def test_summarize_by_with_alias(self):
        rows = q("Perf | where CounterName == 'CPU' "
                 "| summarize Avg = avg(CounterValue) by Computer")
        self.assertEqual(rows, [
            {"Computer": "web-01", "Avg": 85.0},
            {"Computer": "web-02", "Avg": 40.0},
            {"Computer": "db-01", "Avg": None},
        ])
        self.assertEqual(list(rows[0].keys()), ["Computer", "Avg"])

    def test_summarize_by_bin_datetime(self):
        rows = q("Perf | where CounterName == 'CPU' "
                 "| summarize count() by bin(TimeGenerated, 1h)")
        self.assertEqual(rows, [
            {"TimeGenerated": DT("2026-07-03T11:00:00"), "count_": 4},
        ])

    def test_summarize_empty_input_still_one_row(self):
        rows = q("Perf | where CounterValue > 1000 | summarize count(), sum(CounterValue)")
        self.assertEqual(rows, [{"count_": 0, "sum_CounterValue": None}])

    def test_count_operator(self):
        self.assertEqual(q("Perf | count"), [{"Count": 5}])
        self.assertEqual(q("Perf | where Computer == 'nope' | count"), [{"Count": 0}])

    def test_by_expression_needs_alias(self):
        with self.assertRaises(KqlError) as cm:
            q("Perf | summarize count() by CounterValue * 2")
        self.assertIn("alias", str(cm.exception))

    def test_agg_outside_summarize(self):
        with self.assertRaises(KqlError) as cm:
            q("Perf | where sum(CounterValue) > 1")
        self.assertIn("summarize", str(cm.exception))


class OrderingTests(unittest.TestCase):
    def test_top_default_desc_nulls_last(self):
        rows = q("Perf | top 5 by CounterValue")
        vals = [r["CounterValue"] for r in rows]
        self.assertEqual(vals, [90.0, 80.0, 55.0, 40.0, None])

    def test_top_asc_and_limit_n(self):
        rows = q("Perf | top 2 by CounterValue asc")
        self.assertEqual([r["CounterValue"] for r in rows], [40.0, 55.0])

    def test_sort_multi_key_and_stability(self):
        rows = q("Perf | sort by Computer asc, CounterValue desc")
        self.assertEqual(
            [(r["Computer"], r["CounterValue"]) for r in rows],
            [("db-01", None), ("web-01", 90.0), ("web-01", 80.0),
             ("web-02", 55.0), ("web-02", 40.0)])
        # ties keep input order (stable)
        tables = {"T": [{"k": 1, "seq": i} for i in range(4)]}
        rows = run_query("T | sort by k asc", tables)
        self.assertEqual([r["seq"] for r in rows], [0, 1, 2, 3])

    def test_order_by_alias_defaults_desc(self):
        rows = q("Perf | order by CounterValue")
        self.assertEqual(rows[0]["CounterValue"], 90.0)
        self.assertIsNone(rows[-1]["CounterValue"])  # nulls last on desc too

    def test_take_and_limit(self):
        self.assertEqual(len(q("Perf | take 2")), 2)
        self.assertEqual(len(q("Perf | limit 3")), 3)
        self.assertEqual(len(q("Perf | take 99")), 5)


class DistinctTests(unittest.TestCase):
    def test_distinct_columns(self):
        rows = q("Perf | distinct Computer")
        self.assertEqual(rows, [{"Computer": "web-01"}, {"Computer": "web-02"},
                                {"Computer": "db-01"}])
        rows = q("Perf | distinct Computer, CounterName")
        self.assertEqual(len(rows), 4)

    def test_distinct_star(self):
        tables = {"T": [{"a": 1, "b": 2}, {"a": 1, "b": 2}, {"a": 1, "b": 3}]}
        rows = run_query("T | distinct *", tables)
        self.assertEqual(rows, [{"a": 1, "b": 2}, {"a": 1, "b": 3}])


class TimeTests(unittest.TestCase):
    def test_ago_with_injected_now(self):
        rows = q("Perf | where TimeGenerated > ago(1h) | project Computer")
        self.assertEqual([r["Computer"] for r in rows],
                         ["web-01", "web-01", "web-02", "db-01"])
        rows = q("Perf | where TimeGenerated > ago(30m) | count")
        self.assertEqual(rows, [{"Count": 3}])

    def test_now_and_datetime_literal(self):
        rows = q("Perf | take 1 | project N = now(), "
                 "D = datetime(2026-07-03T11:00:00) + 30m")
        self.assertEqual(rows[0]["N"], DT(NOW))
        self.assertEqual(rows[0]["D"], DT("2026-07-03T11:30:00"))

    def test_ago_without_now_errors(self):
        tables = perf_tables()
        del tables["@now"]
        with self.assertRaises(KqlError) as cm:
            run_query("Perf | where TimeGenerated > ago(1h)", tables)
        self.assertIn("@now", str(cm.exception))
        with self.assertRaises(KqlError):
            run_query("Perf | extend N = now()", tables)

    def test_timespan_literals(self):
        rows = q("Perf | take 1 | project A = 2d, B = 90m, C = 250ms")
        self.assertEqual(rows[0]["A"], timedelta(days=2))
        self.assertEqual(rows[0]["B"], timedelta(minutes=90))
        self.assertEqual(rows[0]["C"], timedelta(milliseconds=250))


class StringTests(unittest.TestCase):
    def test_has_vs_contains(self):
        tables = {"Logs": [{"Msg": "error in disk controller"},
                           {"Msg": "controllers rebooted"},
                           {"Msg": "all OK"}]}
        # contains: case-insensitive substring -> matches both controller rows
        rows = run_query("Logs | where Msg contains 'Controller'", tables)
        self.assertEqual(len(rows), 2)
        # has: whole-token match -> only the exact token
        rows = run_query("Logs | where Msg has 'controller'", tables)
        self.assertEqual(rows, [{"Msg": "error in disk controller"}])
        rows = run_query("Logs | where Msg !contains 'controller'", tables)
        self.assertEqual(rows, [{"Msg": "all OK"}])

    def test_startswith_endswith_case_insensitive(self):
        rows = q("Perf | where Computer startswith 'WEB' | distinct Computer")
        self.assertEqual(len(rows), 2)
        rows = q("Perf | where Computer endswith '-01' | distinct Computer")
        self.assertEqual([r["Computer"] for r in rows], ["web-01", "db-01"])

    def test_in_and_not_in(self):
        rows = q("Perf | where Computer in ('web-01', 'db-01') | distinct Computer")
        self.assertEqual(len(rows), 2)
        rows = q("Perf | where Computer !in ('web-01', 'web-02') | distinct Computer")
        self.assertEqual(rows, [{"Computer": "db-01"}])
        # in is case-sensitive
        rows = q("Perf | where Computer in ('WEB-01') | count")
        self.assertEqual(rows, [{"Count": 0}])

    def test_case_sensitivity_eq_vs_tilde(self):
        rows = q("Perf | where Computer == 'WEB-01' | count")
        self.assertEqual(rows[0]["Count"], 0)          # == is case-sensitive
        rows = q("Perf | where Computer =~ 'WEB-01' | count")
        self.assertEqual(rows[0]["Count"], 2)          # =~ is not
        rows = q("Perf | where Computer !~ 'web-01' | count")
        self.assertEqual(rows[0]["Count"], 3)

    def test_string_functions(self):
        rows = q("Perf | take 1 | project "
                 "A = strcat('x', 1, '-', true), B = strlen('hello'), "
                 "C = tolower('AbC'), D = toupper('AbC'), E = tostring(42), "
                 "F = toint('17'), G = todouble('2.5'), H = toint('oops')")
        self.assertEqual(rows[0], {"A": "x1-true", "B": 5, "C": "abc",
                                   "D": "ABC", "E": "42", "F": 17,
                                   "G": 2.5, "H": None})

    def test_iff_isempty_bin_numeric(self):
        rows = q("Perf | project V = iff(CounterValue > 50, 'high', 'low'), "
                 "E = isempty(CounterValue), NE = isnotempty(Computer), "
                 "B = bin(CounterValue, 25)")
        self.assertEqual(rows[0]["V"], "high")
        self.assertEqual(rows[2]["V"], "low")
        self.assertIs(rows[4]["E"], True)
        self.assertIs(rows[0]["NE"], True)
        self.assertEqual([r["B"] for r in rows], [75, 75, 25, 50, None])


class NullSemanticsTests(unittest.TestCase):
    def test_null_comparisons_are_false(self):
        tables = {"T": [{"a": 1}, {"a": None}, {}]}
        self.assertEqual(run_query("T | where a > 0 | count", tables), [{"Count": 1}])
        self.assertEqual(run_query("T | where a < 99 | count", tables), [{"Count": 1}])
        self.assertEqual(run_query("T | where a == 1 | count", tables), [{"Count": 1}])
        self.assertEqual(run_query("T | where a != 1 | count", tables), [{"Count": 0}])
        self.assertEqual(run_query("T | where b contains 'x' | count", tables),
                         [{"Count": 0}])

    def test_null_arithmetic_and_aggregates(self):
        tables = {"T": [{"a": 1}, {"a": None}, {"a": 3}]}
        rows = run_query("T | extend b = a + 1", tables)
        self.assertEqual([r["b"] for r in rows], [2, None, 4])
        rows = run_query("T | summarize count(), sum(a), avg(a), dcount(a)", tables)
        self.assertEqual(rows[0], {"count_": 3, "sum_a": 4, "avg_a": 2.0, "dcount_a": 2})

    def test_missing_column_projects_null(self):
        rows = run_query("T | project ghost", {"T": [{"a": 1}]})
        self.assertEqual(rows, [{"ghost": None}])


class ErrorTests(unittest.TestCase):
    def test_unknown_table(self):
        with self.assertRaises(KqlError) as cm:
            q("Nope | count")
        self.assertIn("unknown table 'Nope'", str(cm.exception))
        self.assertIn("Perf", str(cm.exception))  # lists available tables

    def test_unsupported_operator_named(self):
        with self.assertRaises(KqlError) as cm:
            q("Perf | mv-expand Computer")
        msg = str(cm.exception)
        self.assertIn("unsupported operator 'mv-expand'", msg)
        self.assertIn("summarize", msg)  # supported list included
        with self.assertRaises(KqlError) as cm:
            q("Perf | join Perf")
        self.assertIn("unsupported operator 'join'", str(cm.exception))

    def test_unsupported_function_named(self):
        with self.assertRaises(KqlError) as cm:
            q("Perf | where parse_json(Computer) == 1")
        self.assertIn("unsupported function 'parse_json()'", str(cm.exception))

    def test_syntax_errors(self):
        with self.assertRaises(KqlError):
            q("Perf | where CounterValue >")          # dangling operator
        with self.assertRaises(KqlError):
            q("Perf | take lots")                     # non-integer count
        with self.assertRaises(KqlError):
            q("| where 1 == 1")                       # no table name
        with self.assertRaises(KqlError):
            q("Perf | where 'unterminated")           # bad string
        with self.assertRaises(KqlError) as cm:
            q("Perf | summarize median(CounterValue)")
        self.assertIn("unsupported aggregation 'median'", str(cm.exception))


class CommentsWhitespaceTests(unittest.TestCase):
    def test_comments_and_newlines(self):
        rows = q("""
            // grab busy CPU samples
            Perf
            | where CounterName == 'CPU'   // only CPU
            | where CounterValue > 50
            | count
        """)
        self.assertEqual(rows, [{"Count": 2}])


class RowsEqualTests(unittest.TestCase):
    def test_unordered_default(self):
        a = [{"x": 1}, {"x": 2}]
        b = [{"x": 2}, {"x": 1}]
        self.assertTrue(rows_equal(a, b))
        self.assertFalse(rows_equal(a, b, ordered=True))
        self.assertTrue(rows_equal(a, list(a), ordered=True))

    def test_multiset_semantics(self):
        self.assertFalse(rows_equal([{"x": 1}, {"x": 1}], [{"x": 1}, {"x": 2}]))
        self.assertFalse(rows_equal([{"x": 1}], [{"x": 1}, {"x": 1}]))

    def test_float_tolerance(self):
        self.assertTrue(rows_equal([{"v": 0.1 + 0.2}], [{"v": 0.3}]))
        self.assertFalse(rows_equal([{"v": 0.3001}], [{"v": 0.3}]))
        self.assertTrue(rows_equal([{"v": 1}], [{"v": 1.0}]))  # int vs float ok

    def test_key_mismatch(self):
        self.assertFalse(rows_equal([{"x": 1}], [{"y": 1}]))


class FixtureAndCliTests(unittest.TestCase):
    def _write(self, tmp, name, content):
        path = os.path.join(tmp, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
        return path

    def test_load_fixture_converts_iso_strings(self):
        with tempfile.TemporaryDirectory() as tmp:
            fx = self._write(tmp, "f.json", json.dumps({
                "@now": NOW,
                "T": [{"when": "2026-07-03T10:30:00", "sku": "2026-ABC", "n": 1}],
            }))
            tables = load_fixture(fx)
            self.assertEqual(tables["T"][0]["when"], DT("2026-07-03T10:30:00"))
            self.assertEqual(tables["T"][0]["sku"], "2026-ABC")  # not a timestamp
            rows = run_query("T | where when > ago(2h) | count", tables)
            self.assertEqual(rows, [{"Count": 1}])

    def test_cli_json_lines_and_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            fx = self._write(tmp, "f.json", json.dumps(
                {"T": [{"a": 1, "b": "x"}, {"a": 2, "b": "y"}]}))
            qf = self._write(tmp, "q.kql", "T | where a > 1 | project b")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                rc = main([fx, qf])
            self.assertEqual(rc, 0)
            self.assertEqual([json.loads(line) for line in out.getvalue().splitlines()],
                             [{"b": "y"}])
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                rc = main(["--table", fx, qf])
            self.assertEqual(rc, 0)
            lines = out.getvalue().splitlines()
            self.assertEqual(lines[0].strip(), "b")
            self.assertEqual(lines[2].strip(), "y")

    def test_cli_error_exit_code(self):
        with tempfile.TemporaryDirectory() as tmp:
            fx = self._write(tmp, "f.json", json.dumps({"T": []}))
            qf = self._write(tmp, "q.kql", "T | mv-expand x")
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                rc = main([fx, qf])
            self.assertEqual(rc, 2)
            self.assertIn("mv-expand", err.getvalue())
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertNotEqual(main([]), 0)  # usage error


if __name__ == "__main__":
    unittest.main()
