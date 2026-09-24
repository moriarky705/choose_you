---
name: choose-you-dev-loop
description: >-
  Run a change to the choose_you repository through the three-role loop: the main session (Opus) writes the plan,
  the choose-you-implementer subagent (Sonnet) writes the code, and the choose-you-reviewer subagent (Opus) verifies it.
  Use when the user asks to implement, fix, or refactor something in this repo and wants the plan/implement/review
  split, or says "開発ループで", "計画→実装→レビューで", "/choose-you-dev-loop".
---

# choose_you dev loop

Roles are fixed by model:

| Role | Who | Model |
|---|---|---|
| Plan | this session | Opus (the session's model; if the session is not on Opus, tell the user to run `/model opus` first) |
| Implement | `choose-you-implementer` subagent | Sonnet (pinned in `.claude/agents/choose-you-implementer.md`) |
| Review | `choose-you-reviewer` subagent | Opus (pinned in `.claude/agents/choose-you-reviewer.md`) |

Do not let roles bleed: the planner does not write code, the implementer does not make design decisions, the reviewer does not edit.

## 1. Plan (this session)

Investigate enough to write a plan the implementer can execute without judgment calls. Read the relevant files yourself; do not delegate understanding.

The plan must contain:

- **Goal**: one sentence, plus the concrete evidence that motivated it (a bug reproduction, a UX problem observed in the browser).
- **Files to change**: path and what changes in each, with line references where useful. Call out explicitly when both storage backends or both delivery paths (ActionCable + polling JSON) are affected.
- **Steps**: ordered, each one small enough to verify on its own.
- **Acceptance checks**: commands the implementer must run and the expected outcome. Always include the rspec run and, for JS changes, `npm run build`. Name the specs to add or update.
- **Out of scope**: what not to touch, so the implementer does not "improve" adjacent code.

Show the plan to the user and get agreement before spawning anything, unless the user has already asked to proceed autonomously.

## 2. Implement (choose-you-implementer, Sonnet)

Spawn with `Agent(subagent_type: "choose-you-implementer")`. The prompt is the full plan, verbatim, plus: "Report in the format your agent definition specifies." Do not summarize the plan; the subagent starts with zero context.

If the implementer returns open questions, answer them yourself (you are the planner) and continue the same agent with `SendMessage` rather than starting a new one.

## 3. Review (choose-you-reviewer, Opus)

Spawn with `Agent(subagent_type: "choose-you-reviewer")`. The prompt contains: the plan verbatim, the implementer's full report verbatim, and the list of changed files. Ask for the review format in its agent definition.

## 4. Close the loop

- **REQUEST CHANGES**: send the findings to the same implementer agent via `SendMessage` (do not re-spawn), then re-run the reviewer on the fixed result. Cap at two fix rounds; if still failing, stop and bring the disagreement to the user with both sides stated.
- **APPROVE / APPROVE WITH NITS**: read the diff yourself once (trust but verify). For UI or real-time changes, check it in the browser with the `/choose-you-ops` browser-check flow (owner + participant sessions). Then report to the user: what changed, the verification output, and any nits left open.

Never report a task as done on the implementer's word alone. Do not commit or push unless the user asks.
