# Build across a version/OS matrix in GitHub Actions

The library must be verified against several runtime versions on more than one
operating system, and the jobs should fan out in parallel. Use a **build
matrix** instead of copy-pasting the job.

Edit `ci.yml` in your workspace so that the `build` job:

1. Declares a `strategy.matrix` with **two axes**:
   - a version axis (e.g. `node-version` / `python-version` / `dotnet-version`)
     holding **at least three** values, and
   - an `os` axis holding **at least two** operating systems (for example
     `ubuntu-latest` and `windows-latest`).
2. Sets `runs-on` from the matrix OS axis — i.e. `runs-on:` must reference
   `matrix.os` (via `${{ matrix.os }}`), so each OS gets its own leg.
3. Uses the matrix version value inside a step (a setup action's `with:` block
   or a `run:` command that references the matrix version).

Graded on **structure** — any language/version/OS choice that fills the shape
passes. Parsed by `tools/yamlmini.py`; keep to plain block YAML (no anchors,
tags, or tabs).

Check the axes parse:

```sh
python3 tools/yamlmini.py ci.yml --get jobs.build.strategy.matrix
```
