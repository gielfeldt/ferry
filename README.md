# ferry

Carry Claude Code sessions between machines, using a git repo you control.

Claude Code keeps each conversation as a transcript on the machine it ran on.
ferry copies one into an encrypted git repo — a **store** — and back out again
somewhere else, so you can start work on one laptop and pick it up on another.
Memory travels the same way.

```sh
# on the laptop that has the session
ferry save bug-hunt to work:acme

# on the other one
ferry load work:acme/bug-hunt
claude --resume 3f9a1c2e-…
```

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
```

Needs python3 and git. Nothing else — no packages, no runtime, no daemon.
Or just drop the single `ferry` file anywhere on your `PATH`.

## Quick start

You need a **private** git repo to hold the sessions, encrypted, because
transcripts are conversations. Create one, then:

```sh
# turn it into an encrypted store, once ever
git clone git@github.com:you/sessions.git
cd sessions
printf '*  filter=git-crypt diff=git-crypt\n.gitattributes !filter !diff\n' > .gitattributes
git-crypt init
git add .gitattributes && git commit -m "encrypt everything" && git push
git-crypt export-key ~/sessions.key      # keep this safe - it is the only key

# register it, once per machine
ferry add work git@github.com:you/sessions.git --key ~/sessions.key

# use it
cd ~/develop/acme
ferry sessions                           # what can I send?
ferry save bug-hunt to work:acme
```

`--key` hands your key to `git-crypt unlock`; ferry stores no keys itself.
Encrypting `*` means no path in the store can be committed in the clear by
accident.

## Usage

```
ferry add <name> <git-url> [--key <file>] [--path <dir>]
ferry stores
ferry sessions
ferry memory
ferry save <session> [to] <store>:<dir> [--force]
ferry save --memory [to] <store>:<dir> [--force]
ferry load <store>:<path> [--force]
ferry load --memory <store>:<dir> [--force]
ferry list [<store>[:<path>]]
ferry update [<store>]
```

```sh
ferry add work git@github.com:you/sessions.git --key ~/sessions.key
ferry add work --path ~/develop/sessions      # adopt a checkout you have
ferry stores

ferry sessions                                # sessions in this directory
ferry memory                                  # notes in this directory

ferry save bug-hunt to work:acme              # -> acme/bug-hunt.jsonl
ferry save --memory to work:acme              # -> acme/memory/

ferry list work
ferry load work:acme/bug-hunt                 # a session
ferry load --memory work:acme                 # that folder's memory
ferry update work                             # pull, and explain a divergence
```

[COOKBOOK.md](COOKBOOK.md) works through the situations you will actually hit.

## Concepts

**Everything is relative to the directory you are standing in.** Claude Code
files transcripts by working directory, so `sessions`, `save` and `load` all act
on the current one. `cd` to where you were working.

**A session is filed under its own name.** `save` takes a *directory* and names
the file after the session, so one conversation has one name on every machine.
Names come from `/rename` and live only in `~/.claude/history.jsonl` — never in
the transcript — so a session with no name cannot be saved, and a loaded one
arrives unnamed until you `/rename` it. `load` prints the command for that.

**`load` takes a whole path**, because there you are choosing among what the
store holds rather than deciding where something goes.

**Memory belongs to a directory, not a session.** Claude keeps it in
`memory/*.md` beside the transcripts, shared by everything started there.
`--memory` is a flag rather than a name, so it can never be confused with a
session that happens to be called `memory`.

**A store is a plain git repo.** ferry only fast-forwards; it never merges.

## What it protects you from

| | |
|---|---|
| a shorter copy overwriting a longer one | refused — transcripts only grow, so that means lost turns |
| a different session overwriting a name | refused — the id inside the file is checked, not just the path |
| committing transcripts unencrypted | refused unless `--allow-plaintext` |
| overwriting memory that already has notes | refused without `--force` |
| a diverged clone | reported by `update`, which explains the two ways out |

`--force` overrides the first four, when you mean it.

## How it works

Claude Code stores transcripts in `~/.claude/projects/<slug>/`, where `<slug>`
is the directory's absolute path with every non-alphanumeric character replaced
by `-`, truncated to 200 characters plus a hash if longer. ferry computes the
same name, copies the `.jsonl` out or in, and commits.

In the store:

```
acme/bug-hunt.jsonl     a transcript - the filename is its name
acme/memory/            a memory directory, as .md files
```

Plain files in plain directories. You can rearrange them with `mv` and delete
them with `rm`, without ferry's help.

Only `save` writes to the remote. `load`, `list` and `update` never push, and
`list` fetches without merging so it can always show what is really there,
even when your clone has diverged.

## Limitations

- **Copies, not sync.** Saving replaces the store's copy with yours; loading
  replaces yours with the store's. No merging, and nothing happens on its own.
- **Memory is replaced wholesale**, so notes that exist only on the other
  machine are lost when you save over them.
- **Collisions are caught, not resolved.** ferry stops and tells you.
- **Session names are local.** Loading can only suggest a name, not set one.
- **git-crypt hides contents, not names.** Directory and file names, sizes and
  commit messages stay readable, so keep the store private.

## Tests

```sh
./test
```

Self-contained: no git, no network, no `~/.claude`. Runs on CI unchanged.

## License

[MIT](LICENSE)
