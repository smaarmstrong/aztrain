# Automate release notes from Git history

Release management is tired of hand-writing changelogs. You've been asked to
make release documentation fall out of the Git history automatically, the
moment a release is cut.

Edit `release-notes.yml` in your workspace (a GitHub Actions workflow) so that:

1. It **triggers when a release tag is pushed** (e.g. a `v*.*.*` tag) — not on
   every push to `main`. (Triggering on the `release` event is also accepted.)
2. It checks the repo out with **full history** so `git log` can see previous
   tags (`fetch-depth: 0`).
3. A step **generates the notes/changelog from Git history** — e.g. a
   `git log` range between the previous tag and this one (a changelog tool such
   as git-cliff/conventional-changelog is equally fine).
4. A step **publishes a GitHub Release** for the tag carrying those generated
   notes.

Graded on the workflow **structure** — any workflow that triggers on a
tag/release, reads full history, generates notes from Git, and publishes a
release will pass. Keep the YAML anchor/alias/tag free.

Objective: *Automate creation of documentation from Git history.*
