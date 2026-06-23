# Execution Control Loop (ECL) Guideline (ECL.md)

This document outlines the Execution Control Loop (ECL) rules for managing changes in Paycif.

## 1. Context Loading Order

When booting up a new development session, the agent must load context in the following sequence:
1. Read `AGENT.md` (Harness & Guardrails)
2. Read `docs/ECL.md` (ECL rules)
3. Check for any active task files under the active change directory (e.g. `harness/changes/active/` or project planning logs).
4. Read `docs/STATUS.md` (Current project status, recent changes, handoff notes).
5. Load task-specific project files (e.g., `README.md`, `design.md`).

## 2. Classification of Changes

To maintain safety and speed, changes must be classified as either Small or Structured:

| Category | Definition | Process |
| :--- | :--- | :--- |
| **Small Change** | Localized UI tweaks, comments, styling updates, or single-file fixes without API, data, permission, or architecture impact. | Can be planned briefly in chat and executed immediately without formal approval. |
| **Structured Change** | Any cross-file/module modification, database schema updates, API contract changes, security/permission updates, or architecture-level changes. | Requires creating a plan, saving it, and obtaining explicit user approval before execution. |

## 3. Structured Change Stages

For all Structured Changes, the implementation must follow these stages:
1. **Intake & Specification (`spec.md`)**: Define WHAT is being built, the target users, success criteria, constraints, and assumptions.
2. **Implementation Plan (`plan.md` or `implementation_plan.md`)**: Define HOW the changes will be made (files to modify/create/delete) and trace risks (using MONOPOLY tags).
3. **Execution Tasks Checklist (`tasks.md` or `task.md`)**: A granular list of TODO items mapping code adjustments. Mark items as completed as you go.
4. **Verification & Review (`review.md`)**: Record how the changes were verified (unit tests, manual scripts, build verification).

## 4. Change State Lifecycle

- **Active**: Current changes being developed.
- **Parked**: Changes on hold due to blockages or reprioritization.
- **Archived**: Completed and committed changes. Rebuild the change index after closing a change.
