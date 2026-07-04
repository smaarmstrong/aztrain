# Make every PR traceable to an Azure Boards work item

Your org runs GitHub for code and Azure Boards for planning. Auditors want
every change traceable back to a work item. Azure Boards + GitHub links commits
and PRs to work items via the `AB#<id>` mention syntax — so make that mandatory.

Two files in your workspace:

1. **`pull_request_template.md`** — add a **Work item** section that prompts
   contributors to link the Azure Boards work item using the `AB#<id>` syntax.
2. **`require-workitem.yml`** — a GitHub Actions workflow that runs on
   **`pull_request`** events and **fails the check unless the PR title or body
   contains an `AB#<id>` reference** (e.g. `AB#1234`).

Graded structurally: the template must prompt for `AB#`, and the workflow must
trigger on `pull_request` and have a step that enforces the `AB#` link
(failing when it's missing). Keep the YAML anchor/alias/tag free.

Objective: *Configure integration between Azure Boards and GitHub repositories.*
