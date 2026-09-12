---
applyTo: "**"
---

# Lil Rabbit Mandatory Improvement and Usability Loop

For every substantial implementation, architecture change, automation, workflow change, dependency adoption, UI change, release candidate, or milestone, the lead agent must obtain two independent reviews before declaring DONE whenever the environment supports custom-agent delegation.

1. Invoke `continuous-improvement-challenger` after the first viable solution exists. Its required question is: **What can we do to make this better without adding wasteful complexity?** It reviews reliability, reuse, daily usability, speed, automation, simplicity, maintainability, accessibility, safety, testing, error recovery, observability, future reuse, and existing internal or trusted external capabilities. Classify each recommendation as ACCEPT NOW, DEFER, or REJECT.

2. Before DONE, invoke `daily-use-acceptance-verifier`. Its required questions are: **Did we actually make this better? What specifically became stronger for daily use? Can the intended user use the completed program or workflow immediately without a developer beside them? Is the work genuinely complete at a fully functional and usable checkpoint?** It must inspect actual evidence, tests, preview/runtime when available, failure behavior, regression risk, operational documentation, and the last-known-good checkpoint.

The verifier returns PASS, RETURN, or BLOCKED. DONE is allowed only after PASS. RETURN requires fixes and re-verification. BLOCKED must preserve the last verified usable state and identify the exact external blocker.

If custom-agent delegation is unavailable, perform both roles explicitly in the parent agent and state that delegation was unavailable. Never claim a subagent ran unless it actually ran.

A program or workflow is immediately usable only when the intended user can start or open it, reach the workflow without developer-only intervention, provide real inputs, complete the workflow, receive usable output, recover from ordinary mistakes, persist required results, repeat the workflow without code edits or resets, retain previously working critical workflows, and understand unavoidable limitations.

The improvement question is a quality gate, not permission for endless feature creep. Implement improvements now when they materially strengthen the current milestone, prevent likely failure, remove meaningful daily friction, or reduce avoidable future rework. Defer unrelated ideas.

Target: **smallest reliable solution + independent challenge + proven daily usability + recoverable checkpoint.**