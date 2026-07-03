#!/usr/bin/env python3
"""
kqlgrade.py — grade a learner's KQL query against a fixture and expected rows.

Usage:
    python3 kqlgrade.py <fixture.json> <query.kql> <expected.json> [--ordered]

Runs the query through tools/kqlmini.py (our deterministic KQL-subset engine)
and compares the result to expected.json (a JSON list of row objects) with
float tolerance; --ordered also requires row order to match (use it whenever
the task asks for top/sort). Exit 0 = match, 1 = mismatch/error.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kqlmini


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ordered = "--ordered" in sys.argv
    if len(args) != 3:
        print(__doc__.strip())
        return 1
    fixture_path, query_path, expected_path = args
    try:
        query = Path(query_path).read_text()
    except OSError:
        print(f"✗ no query file at {query_path} — write your KQL there")
        return 1
    if not query.strip():
        print(f"✗ {query_path} is empty — write your KQL there")
        return 1
    tables = kqlmini.load_fixture(fixture_path)
    expected = json.loads(Path(expected_path).read_text())
    try:
        got = kqlmini.run_query(query, tables)
    except Exception as e:
        print(f"✗ query failed: {e}")
        return 1
    if kqlmini.rows_equal(got, expected, ordered=ordered):
        print(f"✓ query returns the expected {len(expected)} row(s)"
              + (" in order" if ordered else ""))
        return 0
    print(f"✗ result mismatch{' (row order matters here)' if ordered else ''}")
    print("  your result:")
    for row in got[:10]:
        print(f"    {json.dumps(row)}")
    if len(got) > 10:
        print(f"    ... ({len(got)} rows total)")
    print(f"  expected {len(expected)} row(s) with columns "
          f"{sorted(expected[0]) if expected else '[]'}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
