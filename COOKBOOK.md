# ferry cookbook

Worked examples. Each one stands alone; skip to the situation you are in.

- [Set up a store from scratch](#set-up-a-store-from-scratch)
- [Add a second machine](#add-a-second-machine)
- [Move a session to the other machine](#move-a-session-to-the-other-machine)
- [Work on both machines, back and forth](#work-on-both-machines-back-and-forth)
- [Share a directory's memory](#share-a-directorys-memory)
- [Keep work and personal apart](#keep-work-and-personal-apart)
- [See what a store holds without changing anything](#see-what-a-store-holds-without-changing-anything)
- [Read a session](#read-a-session)
- [Name a session you never named](#name-a-session-you-never-named)
- [Rename a session](#rename-a-session)
- [Reorganise a store](#reorganise-a-store)
- [Upgrading a store from before 1.2](#upgrading-a-store-from-before-12)
- [Sessions loaded under the wrong id](#sessions-loaded-under-the-wrong-id-before-133)
- [Look before you sync, and back out if you must](#look-before-you-sync-and-back-out-if-you-must)
- [When sync refuses](#when-sync-refuses)
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
the clear because you synced to a folder you had not thought of.

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
`--key`, the clone stays locked and every `sync` is refused until you supply it.

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
#   3f9a1c2e-6b40-4c1a-9f2e-1d5a7c840b31  2026-08-16   1.2 MB  bug-hunt  —
ferry sync work:acme/bug-hunt
```

On the other machine, in whichever directory you want it:

```sh
ferry sync work:acme/bug-hunt
#   resume it here with:  claude --resume bug-hunt

claude --resume bug-hunt
```

The same command on both machines. There is nothing on this one yet, so the
store's copy is the one holding more, and it comes here.

The directory does not have to be the same one, or even the same path, and no
rename is needed — the name is inside the transcript, so it arrives with it.

## Work on both machines, back and forth

The rule is: **sync before you work, sync when you stop.** It is one command,
and it is the same one everywhere:

```sh
# laptop A, finishing up
ferry sync                             # everything here — sent

# laptop B, starting
ferry sync work:acme/bug-hunt          # the first time here, so the whole path
claude --resume bug-hunt
# … work …
ferry sync bug-hunt                    # sent

# laptop A, next morning
ferry sync bug-hunt                    # received
```

You never say which way. ferry compares the two copies and sends whichever
holds everything the other holds, and more — so forgetting which machine you
were last on costs nothing.

If you sync when there is nothing to do, it says so and stops:

```
work:acme/bug-hunt is already in sync
```

And if you worked on **both** machines without syncing in between, each copy
holds turns the other has not. Neither can be copied over the other, so ferry
puts them together instead:

```
merged work:acme/bug-hunt
  318 record(s) in both, 41 only here, 12 only there
sent bug-hunt -> work:acme/bug-hunt  (1.6 MB, +0.1 MB)
  pushed
```

Every record either copy had is kept — yours as they stand, then whatever the
store held that you did not. Nothing is chosen between, and the result is
checked to hold both before it replaces anything.

The session now holds two branches from the point where they parted. Claude
Code reads that natively: it is the same shape a rewind or an edited turn
produces, and most transcripts on a working machine already hold one.
`claude --resume` follows the newest, and `ferry export` shows the lot.

The one thing this cannot settle is a name. If you renamed the session on both
machines, the two disagree about what it is called, and the order of the file
would silently decide:

```
ferry: work:acme/bug-hunt has changed in both places, and the two do not agree
       what it is called:
       here:  bug-hunt-v2
       there: bug-hunt
       joining them would let the order of the file decide the name.
       rename one of them, then sync again
```

## Share a directory's memory

Memory belongs to the directory, not to any session:

```sh
cd ~/develop/acme
ferry memory                        # what is here
ferry sync --memory work:acme       # the store's memory for acme
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
ferry sync --memory work:acme
```

Same command, same rule as a session: whichever side holds every note the other
holds, and more, is the one that gets copied. When each side has notes the
other has not, they are joined — notes are separate files, so keeping both
costs nothing:

```
merged memory work:acme
  7 note(s), 3 of them from the store
```

`MEMORY.md` is rebuilt from both indexes rather than picked between. It is a
list of the notes, one line each, so it follows from them rather than being
something to reconcile — which is why it differing is not a conflict.

The one thing that cannot be joined is the same note saying different things in
each place:

```
ferry: the memory for work:acme has notes that say different things in each place:
       conventions.md
       a note is prose, and picking one would be a guess at what you meant.
```

Nothing is written when it stops. `ferry export --memory work:acme` shows the
store's version to compare against your own; reconcile that one note and sync
again.

## Keep work and personal apart

Two stores, two keys, two sets of eyes:

```sh
ferry add work     git@github.com:you/work-notes.git     --key ~/work.key
ferry add personal git@github.com:you/personal-sessions.git --key ~/personal.key
ferry stores

ferry sync work:accounts/invoice-import
ferry sync personal:admin/house-move
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

## Read a session

Without resuming it, and without hunting for the file:

```sh
ferry export bug-hunt | less                 # in this directory
ferry export work:acme/bug-hunt              # straight out of the store
ferry export ~/develop/acme:bug-hunt         # a session in another directory
```

To find one when you have forgotten where it was:

```sh
ferry sessions --global
#   bug-hunt    2026-08-17   1.2 MB  ~/develop/acme  in sync  work:acme/bug-hunt
#   deploy-fix  2026-08-16   4.0 MB  ~/work/ops      ahead    work:ops/deploy-fix
```

Every path it prints is one `export` can resolve — a session that changed
directory mid-run is listed under the directory its transcript is filed in,
not the one it wandered to.

You get the conversation as markdown — prompts, replies, and a line per tool
call. Tool results are left out, which is most of the file: a 17.9 MB session
prints as 95 KB. When you need to see what actually ran:

```sh
ferry export bug-hunt --tools | less
```

Images are noted where they appeared. To look at them, write them out:

```sh
ferry export bug-hunt --media media > bug-hunt.md
```

which leaves `bug-hunt.md` linking `media/*.jpeg`, so any markdown viewer
shows them in place.

And when you want the file itself rather than a reading of it:

```sh
ferry export bug-hunt --raw > bug-hunt.jsonl
```

That is byte-for-byte the transcript. From a store it is the decrypted
transcript, which is the one place store contents leave the store in the
clear - fine on your own machine, worth knowing before piping it anywhere.

## Name a session you never named

An unnamed session cannot be sent — there would be nothing to call it — and
it is not listed by default, since there is no ref that would reach it. To find
them:

```sh
ferry sessions --all                 # here
ferry sessions --global --all        # everywhere, with what Claude called each
```

The listing shows Claude's own title beside the id, marked `*`, which is often
enough to know what you are looking at:

```
1b94d02f-8c81-4740-adc2-3da7052d0a4a  2026-08-15  3.3 MB  ~/develop/acme  —  * readiness for PR #3 merge
```

Then name it, without opening it:

```sh
ferry name 1b94d02f pr-3-readiness
ferry sync work:acme/pr-3-readiness
```

`ferry name` appends the same record `/rename` writes, so the session answers
to it immediately — `claude --resume pr-3-readiness` — and the name travels
with the transcript to any machine.

### When the title says nothing

Some sessions have no title and open with something unhelpful ("can you resume
this session?"). Read it, or ask for a suggestion — `export` produces exactly
the input for that:

```sh
ferry export ~/develop/acme:94f88b85 | less

ferry export ~/develop/acme:94f88b85 |
    claude -p "suggest a short kebab-case name for this session, name only"
```

ferry does not call a model itself: it has no API keys, no network of its own,
and a listing that quietly cost money would be a poor listing. Piping keeps the
choice of model, prompt and cost yours — and `--tools` is there if the
conversation only makes sense with what it ran.

## Rename a session

The store's filename is the name. Renaming locally does not move anything, so:

```sh
# in Claude Code
/rename better-name

ferry sync work:acme/better-name         # -> acme/better-name.jsonl
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

You name a *directory* and the leaf comes with it. `--memory` says which of the
two you mean, as it does everywhere else.
One commit, pushed, recorded as a rename so history follows the file.

It refuses if something is already at the destination, unless you pass
`--force`, and it works inside one store only — two stores have two keys, so
crossing between them is a `sync` out of one and a `sync` into the other.

Nothing local changes. A machine that already has the old copy still has it,
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

## Sessions loaded under the wrong id, before 1.3.3

Up to 1.3.2, loading a session took the **first** session id inside a
transcript.
That is right for most sessions and wrong for a resumed one: resuming opens the
new transcript with the record the old one was interrupted on, and that record
still carries the old id. So a resumed session was loaded under its *parent's*
id — landing on the parent's transcript, and, because the child is the larger
file, sailing straight past the size check that existed to stop exactly that.
(`ferry sync` replaced that check outright in 1.4; it compares what each copy
holds rather than how big it is.)

Upgrade first, then check each machine. This reads only, and changes nothing:

```sh
python3 - <<'EOF'
import json, pathlib
root = pathlib.Path.home() / ".claude/projects"
for f in sorted(root.glob("*/*.jsonl")):
    sid = None
    for line in open(f, errors="replace"):
        if '"sessionId"' not in line:
            continue
        try:
            r = json.loads(line)
        except ValueError:
            continue
        if r.get("isSidechain") or r.get("type") == "progress":
            continue
        sid = r.get("sessionId") or sid
    if sid and sid != f.stem:
        print(f"{f}\n  should be {sid}.jsonl")
EOF
```

Silence means nothing to do. For anything it prints, look at the name it wants
before moving anything:

```sh
ls ~/.claude/projects/<dir>/<the-id-it-named>.jsonl
```

If that file **does not exist**, rename the mis-named one onto it:

```sh
mv ~/.claude/projects/<dir>/<wrong>.jsonl \
   ~/.claude/projects/<dir>/<right>.jsonl
```

If it **does** exist, stop — that is the session the bad name was taken from,
and overwriting it repeats the original bug. `ferry sync` the store copy again
with a fixed ferry, which now writes the right name, and delete the stale file
once you can see both.

Compacting is not affected and never was: it appends a summary to the same
transcript under the same id, rather than starting a new session.

## Look before you sync, and back out if you must

`ferry sessions` says a copy is ahead or forked. `ferry diff` says of what:

```sh
ferry diff bug-hunt
#   private:acme/bug-hunt
#     267 record(s) in both
#     only here: 1 record(s), none of it conversation
#          session state Claude Code keeps: 1 atis-latch
#     only there: nothing
```

That distinction is the whole point. "Ahead by one record" sounds like work you
would be pushing; here it is Claude Code latching a setting of its own, and
nobody typed anything. A transcript holds both kinds — the conversation, and
the state Claude Code keeps beside it — and only one of them is yours. So diff
counts them apart, and quotes what was actually written:

```
#     only here: 12 record(s) of conversation, and 3 of session state
#          > can you check why the deploy is failing
#          > try the staging cluster instead
```

The two are told apart by whether a record carries a `uuid`: `user`,
`assistant`, `system` and `attachment` do; `mode`, `custom-title`,
`last-prompt`, `atis-latch` and the rest do not.

### Is it safe to reset?

Most session state is disposable because it restates itself: `mode` and
`permission-mode` are written again every turn, `ai-title` is regenerated, and
a latch holds a flag nobody chose. Losing a copy of one costs nothing.

Four are not, and `diff` and `reset` mark them with `!`:

| | |
|---|---|
| `custom-title` | the session's **name**. ferry finds sessions by it, and so does `claude --resume`. Renamed here but not synced? Resetting reverts the name. |
| `file-history-snapshot`, `file-history-delta` | Claude Code's record of file edits, which is what lets you rewind them |
| `queue-operation` | a prompt queued and not yet sent |
| `last-prompt` | which turn a resume carries on from |

So the check is: run `ferry diff`, and if it reports conversation on your side,
or marks any line with `!`, reset will take something you would notice. If it
says *none of it conversation* with no `!`, there is nothing there to lose.

It reads and writes nothing, on either side.

When the work here was a false start, `ferry reset` takes the store's copy and
drops whatever was only local:

```sh
ferry reset bug-hunt
#   resetting private:acme/bug-hunt to the store's copy
#     losing: 12 record(s) - 7 assistant, 5 user
#          > can you check why the deploy is failing
#     gaining: nothing
#   replace this machine's copy? [y/N]
```

It is the only command in ferry that throws work away, so it shows you what
would go and asks. Piped or scripted, with nothing to answer on, it refuses
rather than assuming — `--yes` says you meant it.

`--memory` resets a directory's notes the same way.

Reset goes one way only. There is no reset that discards the store's copy in
favour of this machine's — that is a larger thing to do to a machine you are
not sitting at, and syncing a fork already keeps both without being asked.

## When sync refuses

**"has changed in both places, and the two do not agree what it is called"** —
the session was renamed in both places. The records would join, but the name
cannot: whichever `custom-title` landed last would become the name. Rename one
of them, then sync. Any other fork is joined rather than refused — see
[Work on both machines](#work-on-both-machines-back-and-forth).

**"the memory for … has changed in both places"** — a note was edited on both
machines. Records can be joined; prose cannot. It says which notes differ and
changes nothing; `ferry export --memory <store>:<dir>` shows the store’s.

**"is a different conversation in each place"** — that name is taken in the
store by another conversation. The two ids are printed; `ferry name <id>
<another-name>` frees the name on this machine.

**"nothing called X here, and nothing at store:dir/X"** — neither end has it.
Usually the session was never named: a name is what it would be filed under, so
an unnamed one cannot be referred to at all. `ferry sessions` does not list it
either, so that the list only holds things you can act on — it says how many
are hiding, and `ferry sessions --all` shows them with Claude's own title
marked `*`. A title is not a name; `/rename` it or `ferry name <id> <name>`,
then sync.

**"this clone has diverged from its remote"** — that is git, not the session:
two machines pushed to the store. `ferry update <store>` explains how to sort
it out. Nothing is compared until the pull succeeds, so a stale clone never
reports a fork it does not have.

**"has no git-crypt, so transcripts would be committed in the clear"** — the
store is not encrypted, or your clone is locked. `ferry add <name> --path <dir>
--key <file>` to unlock it.

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
# new private repo, new key, then re-send what still matters
ferry add work2 git@github.com:you/sessions2.git --key ~/sessions2.key
ferry sync work2:acme/bug-hunt
```

The old store's history keeps whatever the old key opens, so delete the repo if
that matters.
