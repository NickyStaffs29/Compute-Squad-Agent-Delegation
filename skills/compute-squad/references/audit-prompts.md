# Audit-grade run: finder and skeptic briefs

Use these on audit-grade runs, after execution and before the PM's verdict. Spawn the five finders in parallel on Sonnet, scoped to the diff and the files Recon mapped. Then run the skeptic on Opus over every finding they return. Only skeptic-CONFIRMED findings count as FAIL evidence.

Every finder returns findings in this format, one per finding, and nothing else:

```
file: <path>
line: <line or range>
claim: <one sentence, what is wrong>
evidence: <the code, command output, or doc text that shows it>
```

A finder that finds nothing returns "no findings" rather than padding the list. Finders never fix anything.

## Finder 1: runtime integrity

Audit the change for behavior that breaks at runtime rather than at compile time. Trace every new or modified code path for unhandled errors, null and undefined access, off-by-one and boundary conditions, unawaited promises, resource leaks, and race conditions between concurrent callers. Check that every failure mode has a defined behavior, not just a happy path. Report each defect with the file, line, the claim, and the evidence that produces it.

## Finder 2: security and privacy

Audit the change for security and privacy regressions. Check authentication and authorization boundaries, input validation and injection surfaces, secrets or credentials in code, logs, or fixtures, and any personal data that newly enters logs, error messages, analytics, or third-party calls. Confirm every invariant Recon flagged under auth, privacy, or logging hygiene still holds after the change. Report each defect with the file, line, the claim, and the evidence.

## Finder 3: dead code and slop

Audit the change for anything shipped that should not have been. Look for unreachable or unused code, functions and exports nobody calls, speculative abstractions with a single caller, commented-out blocks, TODO and placeholder text, debug logging left in, and scope the plan did not ask for. Judge against the plan's task list, not your own taste: anything not traceable to a task is a finding. Report each with the file, line, the claim, and the evidence.

## Finder 4: UI and accessibility

Audit any user-facing surface the change touches. Check keyboard operability and focus order, semantic markup and ARIA correctness, labels and alt text, contrast, error and loading states, and behavior at small viewports. Flag any interactive element reachable by mouse but not by keyboard, and any state change announced visually but not to assistive technology. If the change touches no user-facing surface, return "no findings". Report each defect with the file, line, the claim, and the evidence.

## Finder 5: docs drift

Audit whether the documentation still matches the code after the change. Compare README, in-repo docs, comments, examples, and configuration samples against the actual behavior and signatures the change produced. Flag stale instructions, renamed or removed options still documented, new behavior documented nowhere, and version or count claims that no longer hold. Quote both sides of every contradiction. Report each with the file, line, the claim, and the evidence.

## Skeptic brief (Opus)

You are given one finding from a finder agent. Your job is to refute it, not to confirm it. Read the cited file and line yourself, reconstruct the surrounding context, and try to show the claim is wrong, already handled elsewhere, unreachable in practice, or out of the locked scope. Verify by reproduction where reproduction is possible: run the command, trace the concrete input, or point to the guard that prevents it. Return exactly one verdict, `CONFIRMED` or `REFUTED`, with the reproduction or the reasoning that decided it. Default to `REFUTED` when you are uncertain or cannot reproduce, because an unconfirmed finding costs a re-run for nothing.

For concurrency findings (races, unserialized concurrent writes) and accessibility findings (keyboard operability, ARIA, focus order): failure to reproduce is not refutation. Both classes can be real without reproducing on a given run — a race needs the right interleaving, an accessibility gap needs the right assistive-tech path — so refute only by demonstrating the guard, the serialization point, or the compliant attribute that makes the claim false. Absent that demonstration, CONFIRM. The default-REFUTED-when-uncertain rule above still stands for every other dimension.
