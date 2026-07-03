#!/usr/bin/env python3
"""Unit tests for yamlmini -- run: python3 tools/test_yamlmini.py

Covers the supported subset (nested maps, sequences of maps, scalar type
coercion, quoted-string typing, literal/folded block scalars, comments, flow
collections, document markers), each unsupported-feature error, dig(), and --
as the real determinism/independence check -- parses realistic GitHub Actions
and Azure Pipelines workflows and digs load-bearing values out of them.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import yamlmini
from yamlmini import load, dig, YamlError


class TestScalars(unittest.TestCase):
    def test_int_float_bool_null(self):
        d = load("a: 42\nb: 3.14\nc: true\nd: false\ne: null\nf: ~\ng:\n")
        self.assertEqual(d["a"], 42)
        self.assertIsInstance(d["a"], int)
        self.assertEqual(d["b"], 3.14)
        self.assertIs(d["c"], True)
        self.assertIs(d["d"], False)
        self.assertIsNone(d["e"])
        self.assertIsNone(d["f"])
        self.assertIsNone(d["g"])

    def test_yes_no_are_bools(self):
        d = load("x: yes\ny: no\nz: YES\n")
        self.assertIs(d["x"], True)
        self.assertIs(d["y"], False)
        self.assertIs(d["z"], True)

    def test_plain_string_stays_string(self):
        d = load("name: hello world\nver: 1.2.3\n")
        self.assertEqual(d["name"], "hello world")
        self.assertEqual(d["ver"], "1.2.3")  # not a float: two dots

    def test_unquoted_float_is_float(self):
        d = load("v: 1.0\n")
        self.assertIsInstance(d["v"], float)
        self.assertEqual(d["v"], 1.0)

    def test_negative_and_exponent(self):
        d = load("neg: -7\nexp: 1e3\n")
        self.assertEqual(d["neg"], -7)
        self.assertEqual(d["exp"], 1000.0)


class TestQuotedStrings(unittest.TestCase):
    def test_quoted_numbers_stay_strings(self):
        d = load('a: "1.0"\nb: "0755"\nc: \'42\'\n')
        self.assertEqual(d["a"], "1.0")
        self.assertEqual(d["b"], "0755")
        self.assertEqual(d["c"], "42")
        for v in d.values():
            self.assertIsInstance(v, str)

    def test_double_quote_escapes(self):
        d = load(r'msg: "line1\nline2\ttab\"quote\\slash"')
        self.assertEqual(d["msg"], 'line1\nline2\ttab"quote\\slash')

    def test_single_quote_literal(self):
        d = load("a: 'it''s here'\nb: 'no \\n escape'\n")
        self.assertEqual(d["a"], "it's here")
        self.assertEqual(d["b"], "no \\n escape")


class TestMappingsAndSequences(unittest.TestCase):
    def test_nested_maps(self):
        text = "root:\n  child:\n    leaf: 5\n  other: hi\n"
        d = load(text)
        self.assertEqual(d["root"]["child"]["leaf"], 5)
        self.assertEqual(d["root"]["other"], "hi")

    def test_simple_sequence(self):
        d = load("items:\n  - one\n  - two\n  - 3\n")
        self.assertEqual(d["items"], ["one", "two", 3])

    def test_sequence_of_maps(self):
        text = (
            "people:\n"
            "  - name: Ada\n"
            "    age: 36\n"
            "  - name: Alan\n"
            "    age: 41\n"
        )
        d = load(text)
        self.assertEqual(len(d["people"]), 2)
        self.assertEqual(d["people"][0], {"name": "Ada", "age": 36})
        self.assertEqual(d["people"][1]["name"], "Alan")

    def test_nested_sequences(self):
        text = "grid:\n  -\n    - 1\n    - 2\n  -\n    - 3\n    - 4\n"
        d = load(text)
        self.assertEqual(d["grid"], [[1, 2], [3, 4]])

    def test_sequence_at_key_indent(self):
        # sequence dash at the same indent as its parent key
        text = "on:\n- push\n- pull_request\n"
        d = load(text)
        self.assertEqual(d["on"], ["push", "pull_request"])

    def test_duplicate_key_last_wins(self):
        d = load("k: 1\nk: 2\n")
        self.assertEqual(d["k"], 2)


class TestBlockScalars(unittest.TestCase):
    def test_literal_keeps_newlines(self):
        text = "run: |\n  line one\n  line two\n"
        d = load(text)
        self.assertEqual(d["run"], "line one\nline two\n")

    def test_literal_strip_chomp(self):
        text = "run: |-\n  a\n  b\n"
        d = load(text)
        self.assertEqual(d["run"], "a\nb")

    def test_literal_keep_chomp(self):
        text = "run: |+\n  a\n\n"
        d = load(text)
        self.assertEqual(d["run"], "a\n\n")

    def test_folded_joins_with_spaces(self):
        text = "msg: >\n  the quick\n  brown fox\n"
        d = load(text)
        self.assertEqual(d["msg"], "the quick brown fox\n")

    def test_folded_blank_line_is_break(self):
        text = "msg: >\n  para one\n\n  para two\n"
        d = load(text)
        self.assertEqual(d["msg"], "para one\npara two\n")

    def test_literal_preserves_indentation(self):
        text = "code: |\n  def f():\n      return 1\n"
        d = load(text)
        self.assertEqual(d["code"], "def f():\n    return 1\n")

    def test_block_scalar_then_sibling_key(self):
        text = "run: |\n  echo hi\n  echo bye\nname: after\n"
        d = load(text)
        self.assertEqual(d["run"], "echo hi\necho bye\n")
        self.assertEqual(d["name"], "after")


class TestComments(unittest.TestCase):
    def test_full_line_and_trailing_comment(self):
        text = "# leading\na: 1  # trailing\nb: 2\n"
        d = load(text)
        self.assertEqual(d, {"a": 1, "b": 2})

    def test_hash_inside_quotes_kept(self):
        d = load('color: "#ff0000"\ntag: \'a # b\'\n')
        self.assertEqual(d["color"], "#ff0000")
        self.assertEqual(d["tag"], "a # b")

    def test_hash_without_space_is_string(self):
        d = load("url: http://x/y#frag\n")
        self.assertEqual(d["url"], "http://x/y#frag")


class TestFlowCollections(unittest.TestCase):
    def test_flow_list(self):
        d = load("on: [push, pull_request]\n")
        self.assertEqual(d["on"], ["push", "pull_request"])

    def test_flow_map(self):
        d = load("env: {A: 1, B: two, C: true}\n")
        self.assertEqual(d["env"], {"A": 1, "B": "two", "C": True})

    def test_nested_flow(self):
        d = load("m: {list: [1, 2], inner: {k: v}}\n")
        self.assertEqual(d["m"], {"list": [1, 2], "inner": {"k": "v"}})

    def test_flow_empty(self):
        d = load("a: []\nb: {}\n")
        self.assertEqual(d["a"], [])
        self.assertEqual(d["b"], {})

    def test_flow_quoted_number_stays_string(self):
        d = load('v: ["1.0", 2]\n')
        self.assertEqual(d["v"], ["1.0", 2])
        self.assertIsInstance(d["v"][0], str)


class TestDocumentMarkers(unittest.TestCase):
    def test_leading_marker_ignored(self):
        d = load("---\na: 1\n")
        self.assertEqual(d, {"a": 1})

    def test_trailing_marker_ignored(self):
        d = load("a: 1\n...\n")
        self.assertEqual(d, {"a": 1})

    def test_multiple_documents_error(self):
        with self.assertRaises(YamlError) as cm:
            load("a: 1\n---\nb: 2\n")
        self.assertIn("multiple documents", str(cm.exception))


class TestErrors(unittest.TestCase):
    def test_tab_indent_error(self):
        with self.assertRaises(YamlError) as cm:
            load("a:\n\tb: 1\n")
        self.assertIn("tab", str(cm.exception).lower())

    def test_anchor_error(self):
        with self.assertRaises(YamlError) as cm:
            load("a: &anchor 1\n")
        self.assertIn("anchor", str(cm.exception).lower())

    def test_alias_error(self):
        with self.assertRaises(YamlError) as cm:
            load("a: *ref\n")
        self.assertIn("alias", str(cm.exception).lower())

    def test_tag_error(self):
        with self.assertRaises(YamlError) as cm:
            load("a: !!python/object x\n")
        self.assertIn("tag", str(cm.exception).lower())

    def test_merge_key_error(self):
        with self.assertRaises(YamlError) as cm:
            load("<<: something\n")
        self.assertIn("merge", str(cm.exception).lower())

    def test_error_reports_line_number(self):
        with self.assertRaises(YamlError) as cm:
            load("a: 1\nb: 2\n\tc: 3\n")
        self.assertIn("line", str(cm.exception).lower())


class TestDig(unittest.TestCase):
    def test_dig_hits(self):
        d = load("a:\n  b:\n    - x: 1\n    - x: 2\n")
        self.assertEqual(dig(d, "a", "b", 0, "x"), 1)
        self.assertEqual(dig(d, "a", "b", 1, "x"), 2)
        self.assertEqual(dig(d, "a", "b", -1, "x"), 2)

    def test_dig_misses(self):
        d = load("a:\n  b: 1\n")
        self.assertIsNone(dig(d, "a", "c"))
        self.assertIsNone(dig(d, "z"))
        self.assertIsNone(dig(d, "a", "b", 0))  # b is not a list
        self.assertIsNone(dig(d, "a", "b", "deeper"))

    def test_dig_index_out_of_range(self):
        d = load("a:\n  - 1\n  - 2\n")
        self.assertIsNone(dig(d, "a", 5))


GITHUB_ACTIONS = """\
name: CI
on:
  push:
    branches: [main, dev]
  pull_request:
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          python -m pip install -e .
          python -m pytest -q
      - name: Lint
        run: ruff check .
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo deploying
"""


class TestGitHubActions(unittest.TestCase):
    def setUp(self):
        self.wf = load(GITHUB_ACTIONS)

    def test_top_level(self):
        self.assertEqual(self.wf["name"], "CI")

    def test_on_triggers(self):
        self.assertEqual(dig(self.wf, "on", "push", "branches"), ["main", "dev"])
        self.assertIn("pull_request", self.wf["on"])

    def test_job_names(self):
        self.assertEqual(set(self.wf["jobs"].keys()), {"build", "deploy"})

    def test_runs_on(self):
        self.assertEqual(dig(self.wf, "jobs", "build", "runs-on"), "ubuntu-latest")

    def test_matrix_strategy(self):
        self.assertEqual(
            dig(self.wf, "jobs", "build", "strategy", "matrix", "python"),
            ["3.11", "3.12"],
        )
        # matrix versions must stay STRINGS, not floats
        for v in dig(self.wf, "jobs", "build", "strategy", "matrix", "python"):
            self.assertIsInstance(v, str)

    def test_multiline_run_step(self):
        run = dig(self.wf, "jobs", "build", "steps", 1, "run")
        self.assertEqual(run, "python -m pip install -e .\npython -m pytest -q\n")
        self.assertEqual(dig(self.wf, "jobs", "build", "steps", 1, "name"), "Run tests")

    def test_uses_step(self):
        self.assertEqual(
            dig(self.wf, "jobs", "build", "steps", 0, "uses"),
            "actions/checkout@v4",
        )

    def test_needs(self):
        self.assertEqual(dig(self.wf, "jobs", "deploy", "needs"), "build")


AZURE_PIPELINES = """\
trigger:
  branches:
    include:
      - main
      - releases/*
pool:
  vmImage: ubuntu-latest
variables:
  buildConfiguration: Release
stages:
  - stage: Build
    jobs:
      - job: Compile
        strategy:
          matrix:
            linux:
              imageName: ubuntu-latest
            windows:
              imageName: windows-latest
        steps:
          - script: |
              echo Building
              dotnet build --configuration $(buildConfiguration)
            displayName: Build project
          - task: PublishBuildArtifacts@1
"""


class TestAzurePipelines(unittest.TestCase):
    def setUp(self):
        self.pl = load(AZURE_PIPELINES)

    def test_trigger_branches(self):
        inc = dig(self.pl, "trigger", "branches", "include")
        self.assertEqual(inc, ["main", "releases/*"])

    def test_pool_image(self):
        self.assertEqual(dig(self.pl, "pool", "vmImage"), "ubuntu-latest")

    def test_variables(self):
        self.assertEqual(dig(self.pl, "variables", "buildConfiguration"), "Release")

    def test_stage_and_job_names(self):
        self.assertEqual(dig(self.pl, "stages", 0, "stage"), "Build")
        self.assertEqual(dig(self.pl, "stages", 0, "jobs", 0, "job"), "Compile")

    def test_matrix(self):
        matrix = dig(self.pl, "stages", 0, "jobs", 0, "strategy", "matrix")
        self.assertEqual(matrix["linux"]["imageName"], "ubuntu-latest")
        self.assertEqual(matrix["windows"]["imageName"], "windows-latest")

    def test_multiline_script(self):
        script = dig(self.pl, "stages", 0, "jobs", 0, "steps", 0, "script")
        self.assertEqual(
            script,
            "echo Building\ndotnet build --configuration $(buildConfiguration)\n",
        )
        self.assertEqual(
            dig(self.pl, "stages", 0, "jobs", 0, "steps", 0, "displayName"),
            "Build project",
        )

    def test_task_step(self):
        self.assertEqual(
            dig(self.pl, "stages", 0, "jobs", 0, "steps", 1, "task"),
            "PublishBuildArtifacts@1",
        )


class TestNoThirdPartyImport(unittest.TestCase):
    def test_yaml_not_imported(self):
        # The whole point: yamlmini must never pull in PyYAML.
        self.assertNotIn("yaml", [m for m in sys.modules if m == "yaml"])
        src = open(yamlmini.__file__, encoding="utf-8").read()
        self.assertNotIn("import yaml", src)


if __name__ == "__main__":
    unittest.main(verbosity=2)
