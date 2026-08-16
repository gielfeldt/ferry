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

Make a **private** repo for the sessions themselves — separate from this one —
and encrypt it, because transcripts are conversations:

```sh
git clone git@github.com:you/my-sessions.git
cd my-sessions && git-crypt init && git-crypt export-key ~/my-sessions.key
```

Put that key somewhere safe. Without it the repo is unreadable. Then register it
on each machine:

```sh
ferry repo add mine git@github.com:you/my-sessions.git --key ~/my-sessions.key
```

`--key` clones the repo and hands the key to `git-crypt unlock`. ferry stores no
keys of its own — without it, a fresh clone stays locked and every save is
refused.

ferry refuses to save into a repo that has no git-crypt, unless you pass
`--allow-plaintext`.

## Using it

```sh
ferry sessions                                  # what is in this directory
ferry save <name|id> as <repo>:<path>           # copy it out
ferry save memory as <repo>:<path>              # this directory's memory
ferry load <repo>:<path>                        # copy it back, here
ferry list [<repo>[:<path>]]                    # what a repo holds
ferry update [<repo>]                           # pull it up to date
ferry repo add <alias> <git-url> [--path DIR]
ferry repo list
```

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

**Sessions are addressed by name where possible.** `/rename` names live only in
`~/.claude/history.jsonl`, never in the transcript, so a loaded session arrives
unnamed on the other machine. The name in the repo is simply the filename you
chose, and `load` prints the `/rename` that would restore it. An id prefix works
anywhere a name does.

**Copies never shrink.** Transcripts only grow, so if a `save` or `load` would
replace a longer file with a shorter one, ferry stops — that is the shape of
"I forgot to load first and clobbered yesterday's work". `--force` if you mean it.

## Layout in the repo

```
acme/bug-hunt.jsonl     a transcript - the filename is its name
personal/notes/         a memory directory, as .md files
```

Plain files in plain directories. You can read it, move things around with `mv`,
and delete what you no longer want, without ferry's help.
