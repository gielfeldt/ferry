# Working on ferry

## Documentation is part of the change, not a follow-up

`README.md`, `COOKBOOK.md`, `CONTRIBUTING.md`, `skills/ferry/SKILL.md` and
ferry's own `--help` describe how ferry behaves. When behaviour changes, they
change **in the same commit**. A commit that alters what ferry does and leaves
them saying the old thing has not finished; it has left a second, quieter bug
for someone to find by trusting the docs.

This is not a style preference. It has gone wrong twice here: a `sessions`
example showed a listing ferry has never printed, and the cookbook told you to
`git rm` a file by hand for a rename that ferry had already stopped needing.
Both were wrong for weeks, and both were found by a reader rather than a test.

Before committing, ask what a reader was told before this change and whether it
is still true — and specifically check:

- **`README.md`** — the synopsis, the concept it belongs to, and Limitations
- **`COOKBOOK.md`** — any recipe whose steps this makes unnecessary or wrong
- **`skills/ferry/SKILL.md`** — what Claude is told it may and may not run
- **`ferry`** — `USAGE`, `EXAMPLES`, and the docstring of anything you touched

## Examples use invented names, never real output

Every example — in docs, tests, fixtures, commit and tag messages — uses
placeholders: `acme`, `widgets`, `bug-hunt`, `deploy-fix`. Never paste output
copied from a real machine. When an example needs to look authentic, build a
throwaway store and generate it from that, so there is nothing real to paste.

This repository is public. Session names, store folders, machine names and
paths are not placeholders, and removing them afterwards means rewriting
history that GitHub will keep serving by SHA regardless.

## Say what is true

Report what a change does and does not do. If something is untested, or works
on one machine and not another, or you could not verify it, say so plainly
rather than describing the intent as though it were the result.
