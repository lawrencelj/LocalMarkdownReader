# Independent Verification Rule

## When to Apply

This rule applies after completing any implementation task that:
- Changes application source code
- Modifies application behavior
- Updates tests that affect release behavior
- Changes packaging or build configuration

## Requirement

After passing the four-suite test gate (Unit, Functional, Integration, Security tests), you MUST spawn a second agent to independently verify the implementation before closing the change.

## Verification Process

1. **Complete Implementation**: Finish all code changes and run the four-suite test gate
2. **Spawn Verifier Agent**: Use `invoke_sub_agent` with `general-task-execution` to create an independent verifier
3. **Provide Context**: Give the verifier:
   - The user's original goal and acceptance criteria
   - The candidate revision SHA
   - Instructions to verify independently (not just re-run implementer's tests)
4. **Require Explicit Result**: The verifier must return `ACCEPT` or `REJECT` with evidence
5. **Handle Results**:
   - On `ACCEPT`: Proceed to close the change
   - On `REJECT`: Fix issues, rerun four-suite gate, and repeat verification

## Verifier Agent Prompt Template

```
You are an independent verifier. You did NOT implement the following change and must verify it objectively.

**User Goal:** [describe the original user request]

**Acceptance Criteria:**
[list specific, testable criteria]

**Candidate Revision:** [commit SHA]

**Your Tasks:**
1. Read the modified files and verify they meet the acceptance criteria
2. Run the four test suites independently to confirm they pass
3. Verify version metadata and changelog are updated correctly
4. Test the built/installed artifact if applicable

Provide an explicit **ACCEPT** or **REJECT** result with evidence tied to the candidate revision.
If REJECT, explain exactly what is wrong.
```

## Key Rules

- The verifier MUST NOT be the implementing agent
- The verifier MUST NOT simply re-run the implementer's tests without inspection
- A test infrastructure failure is incomplete verification, not acceptance
- The verifier's ACCEPT must bind to the final candidate SHA
- Any commit after ACCEPT requires the four-suite gate and independent verification to be repeated
