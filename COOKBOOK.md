# ferry cookbook

Worked examples. Each one stands alone; skip to the situation you are in.

- [Set up a store from scratch](#set-up-a-store-from-scratch)
- [Add a second machine](#add-a-second-machine)
- [Move a session to the other machine](#move-a-session-to-the-other-machine)
- [Work on both machines, back and forth](#work-on-both-machines-back-and-forth)
- [Share a directory's memory](#share-a-directorys-memory)
- [Keep work and personal apart](#keep-work-and-personal-apart)
- [See what a store holds without changing anything](#see-what-a-store-holds-without-changing-anything)
- [Rename a session](#rename-a-session)
- [Reorganise a store](#reorganise-a-store)
- [Upgrading a store from before 1.2](#upgrading-a-store-from-before-12)
- [When save refuses](#when-save-refuses)
- [When update says DIVERGED](#when-update-says-diverged)
- [Adopt a checkout you already have](#adopt-a-checkout-you-already-have)
- [Losing a laptop](#losing-a-laptop)

---

## Set up a store from scratch

A store is a private git repo whose contents are encrypted. Create the repo on
your host of choice, then:

```sh
git clone git@github.com:you/sessions.git
cd sessions

printf '*  filter=git-crypt diff=git-crypt\n.gitattributes !filter !diff\n' > .gitattributes
git-crypt init
git add .gitattributes
git commit -m "encrypt everything in this repo"
git push

git-crypt export-key ~/sessions.key
```

Encrypting `*` rather than a list of paths means nothing can be committed in
the clear because you saved to a folder you had not thought of.

Put `~/sessions.key` somewhere safe — a password manager — and keep a copy off
the laptop. Without it the store is unreadable.

```sh
ferry add work --path "$PWD"
ferry stores
```

## Add a second machine

```sh
curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
ferry add work git@github.com:you/sessions.git --key /path/to/sessions.key
ferry list work
```

`ferry add` clones into `~/.local/share/ferry/work` and unlocks it. If you skip
`--key`, the clone stays locked and every `save` is refused until you supply it.

## Move a session to the other machine

Sessions are filed under the name you gave them, so name it first if you have
not:

```sh
# in Claude Code
/rename bug-hunt
```

Then, in the directory you were working in:

```sh
ferry sessions
#   3f9a1c2e-…  2026-08-16   1.2 MB  bug-hunt
ferry save bug-hunt to work:acme
```

On the other machine, in whichever directory you want it:

```sh
ferry update work
ferry load work:acme/bug-hunt
#   resume it here with:  claude --resume bug-hunt

claude --resume bug-hunt
```

The directory does not have to be the same one, or even the same path, and no
rename is needed — the name is inside the transcript, so it arrives with it.

## Work on both machines, back and forth

The rule is: **load before you work, save when you stop.**

```sh
# laptop A, finishing up
ferry save bug-hunt to work:acme

# laptop B, starting
ferry load work:acme/bug-hunt --force     # replace B's older copy
claude --resume bug-hunt
# … work …
ferry save bug-hunt to work:acme

# laptop A, next morning
ferry load work:acme/bug-hunt --force
```

`--force` is needed on `load` when your local copy is *longer* than the store's
— ferry assumes the longer one is newer and refuses to shrink it. If you get
that refusal and you did not expect it, you probably forgot to save on the
other machine.

## Share a directory's memory

Memory belongs to the directory, not to any session:

```sh
cd ~/develop/acme
ferry memory                        # what is here
ferry save --memory to work:acme    # the store's memory for acme
```

To read what the store holds before you take it, ask for memory rather than
sessions — the folder listing tells you which directories have any, and naming
one gives the same output `ferry memory` gives for the directory you are
standing in:

```sh
ferry list --memory work         # every folder that has memory, and how much
ferry list --memory work:acme    # the notes themselves, with descriptions
```

On the other machine:

```sh
cd ~/work/acme
ferry load --memory work:acme
```

Saving replaces the store's copy entirely, so notes that exist only on the
other machine are lost. Load first if in doubt.

## Keep work and personal apart

Two stores, two keys, two sets of eyes:

```sh
ferry add work     git@github.com:you/work-sessions.git     --key ~/work.key
ferry add personal git@github.com:you/personal-sessions.git --key ~/personal.key
ferry stores

ferry save invoice-import to work:accounts
ferry save house-move     to personal:admin
```

Nothing is shared between them — separate repos, separate keys, separate
access.

## See what a store holds without changing anything

```sh
ferry list work                 # every session
ferry list work:acme            # one folder
ferry list --memory work        # the memory it holds instead
```

`list` fetches but never merges, so it always shows what is really on the
remote and can never fail because your clone has drifted. If you are behind it
says so:

```
  2 commit(s) waiting on the remote - ferry update work
```

## Rename a session

The store's filename is the name. Renaming locally does not move anything, so:

```sh
# in Claude Code
/rename better-name

ferry save better-name to work:acme      # -> acme/better-name.jsonl
```

The old file is still there under the old name. Remove it yourself:

```sh
cd ~/.local/share/ferry/work
git rm acme/bug-hunt.jsonl
git commit -m "renamed to better-name"
git push
```

`ferry move` will not do this one. It keeps the leaf, so it can re-file a
session but never rename it — the name is inside the transcript, and only
`/rename` changes it there.

## Reorganise a store

Moving something to another folder, without a local copy of it and without
dropping into git:

```sh
ferry move work:acme/bug-hunt work:archive    # -> archive/bug-hunt.jsonl
ferry move --memory work:acme work:acme-v2    # acme's memory -> acme-v2
ferry move work:old-project work:archive      # a whole folder of sessions
ferry move work:archive/notes work:           # to the top of the store
```

You name a *directory* and the leaf comes with it, the same rule `save`
follows. `--memory` says which of the two you mean, as it does everywhere else.
One commit, pushed, recorded as a rename so history follows the file.

It refuses if something is already at the destination, unless you pass
`--force`, and it works inside one store only — two stores have two keys, so
crossing between them is a `load` and then a `save`.

Nothing local changes. A machine that already loaded the old copy still has it,
under the name it always had.

## Upgrading a store from before 1.2

Stores written by ferry 1.1 and earlier kept both kinds in one place —
`acme/bug-hunt.jsonl` beside `acme/memory/`. From 1.2 they live in two trees,
so that saving memory can never reach a transcript.

Upgrade **every machine first**, because an older ferry will not find anything
in a migrated store, and a 1.2 one will report a 1.1 store as empty:

```sh
curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
ferry --version        # 1.2.0 or later, everywhere
```

Then move the store across once, by hand — it is a one-off, so ferry has no
command for it:

```sh
cd ~/.local/share/ferry/work
mkdir -p sessions memories

for d in */; do
    d="${d%/}"
    case "$d" in sessions|memories) continue ;; esac
    [ -d "$d/memory" ] && git mv "$d/memory" "memories/$d"
    # a folder that held only memory is empty now, and git mv refuses those
    if [ -n "$(ls -A "$d")" ]; then git mv "$d" "sessions/$d"; else rmdir "$d"; fi
done

git commit -m "split into sessions/ and memories/"
git push
```

Check it before pushing with `git status` and `ferry list work` — the listing
should be identical to the one you got before, dates included. Nothing in
`~/.claude` is touched, and the old paths stay in git history either way.

## When save refuses

**"has no name, and the name is what it would be filed under"** — the session
was never named. `/rename` it, then save. `ferry sessions` shows Claude's own
title with a `*` for exactly these — a title is not a name.

**"already holds a different session"** — that name is taken in the store by
another conversation. Rename one of them, or `--force` if you really mean to
replace it.

**"saving would shrink N -> M bytes"** — the store has a longer copy, so
someone saved from elsewhere after you last loaded. `ferry load` it first, or
`--force` if your copy is genuinely the one you want.

**"has no git-crypt, so this would be committed in the clear"** — the store is
not encrypted, or your clone is locked. `ferry add <name> --path <dir> --key
<file>` to unlock it.

## When update says DIVERGED

Both your clone and the remote have commits the other lacks. ferry will not
merge encrypted content, so it stops and hands you the choice:

```
work: DIVERGED - 1 commit(s) here, 1 on the remote, and they have split.
```

Look at both sides:

```sh
cd ~/.local/share/ferry/work
git log --oneline HEAD...@{u}
```

Then pick one:

```sh
git rebase origin/main        # keep yours, replayed on top
git reset --hard origin/main  # discard yours, take the remote
```

Your sessions in `~/.claude` are untouched either way. The worst case is saving
them again.

## Adopt a checkout you already have

If the store is already cloned somewhere you like:

```sh
ferry add work --path ~/develop/sessions
```

ferry uses that directory instead of cloning its own copy, and reads the URL
from its `origin` remote.

## Losing a laptop

The store is encrypted at rest on the host, so whoever runs that host cannot
read your conversations. What they *can* see is structure: directory names,
file names, sizes and commit messages. Keep the repo private regardless.

If the laptop had the key, assume the key is gone with it. There is no way to
re-encrypt an existing git history usefully — rotating means a new store:

```sh
# new private repo, new key, then re-save what still matters
ferry add work2 git@github.com:you/sessions2.git --key ~/sessions2.key
ferry save bug-hunt to work2:acme
```

The old store's history keeps whatever the old key opens, so delete the repo if
that matters.
