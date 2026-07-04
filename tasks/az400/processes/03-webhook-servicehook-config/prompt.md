# Publish build events to a webhook

An external dashboard needs to hear about builds. Rather than have it poll,
you'll push events to it with an **Azure DevOps service hook** (the "Web Hooks"
consumer, which POSTs a JSON HTTP request on each subscribed event).

Complete `servicehook.json` in your workspace — the body you'd POST to
`_apis/hooks/subscriptions` — so that it:

1. Uses the generic **`webHooks`** consumer with the **`httpRequest`** action.
2. Subscribes to a real **event type** (e.g. `build.complete`).
3. Targets an **HTTPS** webhook `url` under `consumerInputs`.
4. Carries **no inline secret**: if you send an auth header, reference a
   variable/secret (`$(WEBHOOK_TOKEN)`) — never paste the literal token.

Graded by parsing the JSON structurally: any correct subscription with the web
hooks consumer, an event type, an HTTPS target, and no hardcoded credential
passes.

Objective: *Configure integration by using webhooks.*
