# ferry

Carry Claude Code sessions between machines, using a git repo you control.

```sh
# on the laptop that has the session
ferry save bug-hunt as mine:acme/bug-hunt

# on the other one
ferry load mine:acme/bug-hunt
```

`save` copies a transcript out of `~/.claude/projects/<this directory>/` into
the repo, commits and pushes. `load` pulls and copies it back. That is the whole
idea — `scp` with a git repo in the middle.

**Nothing runs on its own.** No hooks, no symlinks, no background sync, no
watching. ferry does exactly what you type, when you type it.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
```

Needs python3 and git. Nothing else.

## Setup

Make a **private** repo for the sessions themselves — the *store* — separate from this one —
and encrypt it, because transcripts are conversations:

```sh
git clone git@github.com:you/my-sessions.git
cd my-sessions && git-crypt init && git-crypt export-key ~/my-sessions.key
```

Put that key somewhere safe. Without it the repo is unreadable. Then register it
on each machine:

```sh
ferry add work git@github.com:you/my-sessions.git --key ~/my-sessions.key
```

`--key` clones the store and hands the key to `git-crypt unlock`. ferry stores no
keys of its own — without it, a fresh clone stays locked and every save is
refused.

ferry refuses to save into a store that has no git-crypt, unless you pass
`--allow-plaintext`.

## Using it

```sh
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
# register a store, once per machine
ferry add work git@github.com:you/sessions.git --key ~/sessions.key
ferry add work --path ~/develop/sessions      # adopt a checkout you have
ferry stores

# what have I got here
ferry sessions
ferry memory

# send it
ferry save bug-hunt to work:acme              # -> acme/bug-hunt.jsonl
ferry save --memory to work:acme              # -> acme/memory/

# fetch it on the other machine
ferry list work
ferry load work:acme/bug-hunt                 # a session
ferry load --memory work:acme                 # that folder's memory
ferry update work
```

A session is filed under its own name, so `save` takes a **directory** and ferry
names the file. `load` is picking one out again, so there you give the whole
path. `--memory` takes a directory in both, since its leaf is always `memory` —
and being a flag, it never collides with a session that happens to be called
`memory`.

`save` and `load` both act on **the directory you are standing in**, because
that is what decides which `~/.claude/projects/` folder Claude uses.

## Who touches git, and when

| | fetches | changes your clone | pushes |
|---|---|---|---|
| `save` | yes | fast-forwards first | yes |
| `load` | yes | fast-forwards first | no |
| `list` | yes | **no** | no |
| `update` | yes | fast-forwards | no |

`list` fetches but never merges, so it always shows what is really on the
remote and can tell you how far behind you are — without ever being the command
that fails. `update` is the one that moves your clone.

ferry never merges. If your clone and the remote have both moved, `update` says
so and shows you the two ways out (`git rebase` or `git reset --hard`), and
leaves the choice to you. Your sessions in `~/.claude` are untouched by any of
it; the worst case is saving them again.

## Two things worth knowing

**A session is filed under its own name.** You give `save` a directory, not a
filename — `ferry save bug-hunt as mine:acme` writes `acme/bug-hunt.jsonl`. One
session therefore has one name everywhere, and ferry refuses to save a session
that has no name, because there would be nothing to call it.

Names live only in `~/.claude/history.jsonl`, never in the transcript, so a
loaded session arrives unnamed on the other machine; `load` prints the
`/rename` that restores it.

**One name, one session.** If the target already holds a transcript with a
different session id inside, `save` refuses rather than replacing a
conversation with an unrelated one — a failure the size check cannot catch,
since the newcomer is usually bigger.

**Copies never shrink.** Transcripts only grow, so if a `save` or `load` would
replace a longer file with a shorter one, ferry stops — that is the shape of
"I forgot to load first and clobbered yesterday's work". `--force` if you mean it.

## Layout in the store

```
acme/bug-hunt.jsonl     a transcript - the filename is its name
personal/notes/         a memory directory, as .md files
```

Plain files in plain directories. You can read it, move things around with `mv`,
and delete what you no longer want, without ferry's help.
