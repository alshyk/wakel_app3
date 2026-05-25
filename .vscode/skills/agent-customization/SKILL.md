# Skill: Create-SKILL (agent-customization)

Purpose
- Convert a multi-step conversation or ad-hoc workflow into a reusable `SKILL.md` that codifies the process, decisions, and acceptance criteria for future automation.

When to use
- You (or the agent) followed a repeatable multi-step procedure during a session and want to capture it as a skill.
- You want a workspace-scoped template so other agents or teammates can reuse the same steps.

Scope
- Workspace-scoped by default (place under `.vscode/skills/<skill-name>/SKILL.md`).
- Can be adapted to personal scope if stated in the conversation.

Inputs
- Conversation transcript or summary.
- Desired outcome (the final artifact produced by the workflow).
- Optional constraints (time limit, tooling available, files to edit).

Outputs
- `SKILL.md` file containing: purpose, trigger, step-by-step procedure, decision points, quality checks, example prompts, and suggested follow-ups.

Step-by-step procedure
1. Review conversation and extract the step sequence.
   - List atomic steps in order (e.g., "Identify failing test", "Run tests", "Patch code", "Run tests again").
   - For each step, capture inputs, outputs, and required tools.
2. Identify decision points and branching logic.
   - State the condition that triggers each branch and the alternative actions.
3. Define quality criteria and completion checks.
   - Include explicit checks (tests pass, linter clean, build succeeds, PR created, user confirmation).
4. Draft the skill content.
   - Provide concise descriptions, helpful examples, and 1–3 example prompts an engineer could use to invoke the skill.
5. Clarify ambiguities.
   - If the conversation doesn't produce a clear workflow, add a short list of clarifying questions.
6. Iterate until criteria are met.
   - Revise based on feedback and finalize the `SKILL.md` file.

Decision points
- If no clear workflow emerges: prompt the user for outcome, scope (workspace or personal), and depth (quick checklist vs full procedure).
- If the workflow depends on specific files or tools: include exact file paths and commands, and mark those as required preconditions.

Quality criteria
- Steps are atomic and ordered.
- Decision points are explicit and testable.
- Acceptance checks are concrete (e.g., `flutter test` passes, `dart analyze` returns no issues).
- Includes example prompts and at least one invocation example.

Template skeleton (copy into new skills)
- Title: short descriptive name
- Purpose: one-line intent
- When to use: short bullets
- Inputs / Outputs
- Steps: numbered atomic steps
- Decision points: concise condition → action
- Quality criteria: pass/fail checklist
- Examples: 2–3 example prompts and expected results
- Follow-ups: suggested related skills or automation

Example prompts
- "Create a SKILL.md from the last conversation capturing the debugging workflow for `lib/screens/gate_screen.dart`."
- "Draft a workspace-scoped skill that codifies our PR creation checklist and testing steps."

Suggested follow-ups
- Add a small test harness or CI check that ensures the skill's acceptance criteria are runnable.
- Create companion `README.md` or a generator script that scaffolds new `SKILL.md` files from a template.

Notes for maintainers
- Keep skills short and focused: prefer many small skills over one large monolith.
- Store skills under `.vscode/skills/<skill-name>/` to keep them discoverable.
- When reusing conversation snippets, redact any sensitive information before saving.

---

Created-by: agent-customization skill template
