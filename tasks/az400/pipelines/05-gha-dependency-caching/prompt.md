# Speed up a GitHub Actions workflow with dependency caching

CI is slow because every run re-downloads all dependencies from scratch. Add
caching so unchanged dependencies are restored from a previous run.

Edit `ci.yml` in your workspace so the `build` job:

1. Has a caching step using **`actions/cache`** (any version) that:
   - sets a `path:` to the dependency directory (e.g. `~/.npm`, `~/.cache/pip`,
     `**/node_modules`), and
   - sets a `key:` that includes a **hash of the lockfile** so the cache
     invalidates when dependencies change — use the `hashFiles(...)` expression
     (e.g. `deps-${{ hashFiles('**/package-lock.json') }}`).
2. Still checks out the code and runs the build after restoring the cache.

Graded on **structure** — any language, any cache path, and any key that
incorporates `hashFiles(...)` passes. The YAML is parsed with
`tools/yamlmini.py`, so stick to plain block YAML (no anchors, tags, or tabs).

```sh
python3 tools/yamlmini.py ci.yml --get jobs.build.steps
```
