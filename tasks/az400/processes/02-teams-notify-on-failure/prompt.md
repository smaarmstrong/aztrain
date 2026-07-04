# Tell Microsoft Teams when the build breaks

Your team lives in Microsoft Teams and keeps missing failed CI runs. Close the
feedback loop: wire the pipeline so a red build pings a Teams channel.

Edit `ci.yml` in your workspace so that, in addition to the existing `build`
job:

1. There is a **notification step that posts to Microsoft Teams** (an incoming
   webhook / Teams action).
2. It fires **only when something fails** — gate it with `if: failure()` (on
   the step, or on a dedicated notify job that `needs` the build). A green run
   must stay quiet.
3. The webhook URL is **read from a secret** (`${{ secrets.* }}`) — do NOT
   paste the `office.com` webhook URL into the YAML.

Graded on structure and secret hygiene: any workflow with a Teams notification
gated on failure and sourcing its webhook from a secret passes. Keep the YAML
anchor/alias/tag free.

Objective: *Configure integration between GitHub or Azure DevOps and Microsoft
Teams.*
