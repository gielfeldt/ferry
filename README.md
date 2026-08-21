# ferry

Carry Claude Code sessions between machines, using a git repo you control.

Claude Code keeps each conversation as a transcript on the machine it ran on.
ferry copies one into an encrypted git repo — a **store** — and back out again
somewhere else, so you can start work on one laptop and pick it up on another.
Memory travels the same way.

```sh
# on the laptop that has the session
ferry sync work:acme/bug-hunt

# on the other one — same command
ferry sync work:acme/bug-hunt
claude --resume bug-hunt
```

One command, both directions. ferry works out which way it needs to go from
what each copy holds, and refuses rather than guess when both have moved.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
```

Or just drop the single `ferry` file anywhere on your `PATH`.

## Requirements

| | |
|---|---|
| **python3**, 3.9 or newer | ferry is one file and imports only the standard library |
| **git** | a store is a git repo; ferry runs `git` for every store operation |
| **git-crypt** | what keeps a store readable only by you — needed on every machine that uses one |
| **curl** or **wget** | only to run `install.sh` — anything remote afterwards is git's doing |

No packages to install, no runtime, no daemon, nothing running in the
background.

git-crypt is not optional in practice. Without it `sync` refuses rather than
committing your conversations in the clear, and a store whose clone is locked
will fail to load from, because what is on disk is ciphertext. `ferry add
<name> --key <file>` is what unlocks a clone.

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
ferry sync work:acme/bug-hunt
```

`--key` hands your key to `git-crypt unlock`; ferry stores no keys itself.
Encrypting `*` means no path in the store can be committed in the clear by
accident.

## Usage

```
ferry add <name> <git-url> [--key <file>] [--path <dir>] [--force]
ferry stores
ferry rename <store> <new-name>
ferry remove <store> [--force]
ferry sessions [<dir>] [--global] [--all]
ferry name <session>|<dir>:<session> <name>
ferry memory [<dir>] [--global]
ferry sync <store>:<path>
ferry sync --memory <store>:<dir>
ferry move <store>:<path> <store>:<dir> [--force]
ferry move --memory <store>:<dir> <store>:<dir> [--force]
ferry export <session>|<store>:<path>|<dir>:<session>
             [--tools] [--media <dir>] [--raw] [--all]
ferry export --memory <dir>[:<note>]|<store>:<dir>[/<note>]
ferry list [<store>[:<path>]]
ferry list --memory [<store>[:<dir>]]
ferry update [<store>]
```

```sh
ferry add work git@github.com:you/sessions.git --key ~/sessions.key
ferry add work --path ~/develop/sessions      # adopt a checkout you have
ferry rename work old-work                    # same store, different name
ferry remove old-work                         # forget it; the clone stays
ferry stores

ferry sessions                                # sessions in this directory
ferry sessions --global                       # every named session, and where
ferry sessions --all                          # unnamed ones too, listed by id
ferry sessions ~/develop/acme                 # another directory, same rules
ferry name 6af148fd deploy-fix                # name one without resuming it
ferry memory                                  # notes in this directory
ferry memory ~/develop/acme                   # notes in another
ferry memory --global                         # every directory that remembers

ferry sync work:acme/bug-hunt                 # a session, either direction
ferry sync --memory work:acme                 # that folder's notes

ferry list work                               # its sessions
ferry list --memory work                      # its memory
ferry list --memory work:acme                 # the notes in one folder
ferry update work                             # pull, and explain a divergence

ferry export bug-hunt                         # read it, as markdown
ferry export --memory work:acme               # a folder's notes, in full
ferry export --memory work:acme/role          # just the one note
ferry export work:acme/bug-hunt --tools       # with what the tools did
ferry export bug-hunt --raw > bug-hunt.jsonl  # the transcript itself

ferry move work:acme/bug-hunt work:archive    # -> archive/bug-hunt.jsonl
ferry move --memory work:acme work:acme-v2    # -> acme-v2/memory
```

[COOKBOOK.md](COOKBOOK.md) works through the situations you will actually hit.

## Concepts

**Everything is relative to the directory you are standing in.** Claude Code
files transcripts by working directory, so `sessions` and `sync` act on
the current one. `cd` to where you were working. The exceptions say so out loud: `sessions` takes a directory to look in
instead, `sessions --global` looks everywhere, and `export` takes a ref that
can name another directory. A directory only says *where* — the flags go on
meaning what they mean, so `ferry sessions ~/develop/acme` lists the named
ones there and `--all` still widens it.

**A session is filed under its own name**, so one conversation has one name on
every machine. The name comes from `/rename`, `/branch` or `claude -n`, and is
recorded inside the transcript — so it travels with the session, and one that
arrives from a store answers to it straight away. A session with no name cannot
be sent; there would be nothing to call it.

`ferry name` sets one without resuming the session, by appending the record
Claude Code would have written — which matters for an old conversation you want
to file but not reopen. Local sessions only: in a store the file *is* named
after the session, so naming one there would leave the two disagreeing.

**`sync` works out its own direction.** You give it one ref — the whole path in
the store — and it compares what each copy holds. Whichever holds everything the
other holds, and more, is the one that gets copied. A copy is never replaced by
one holding less, so there is no direction to get wrong and no flag to get
wrong either.

When each copy holds something the other does not, neither can be written
without dropping it, and `sync` says so and stops. That is the only case it
will not handle, and it is the case worth stopping for.

**`move` re-files, it does not rename.** It takes a path and a directory, and
the leaf goes along unchanged. A session's name lives inside its transcript, so
a move that could rename the file would let the two disagree; not being able to
say a new name means it cannot happen. To rename, `/rename` the session and
sync it again.

**Memory belongs to a directory, not a session.** Claude keeps it in
`memory/*.md` beside the transcripts, shared by everything started there. So
where a session ref names a conversation, a memory ref names a directory —
which is the whole of it, with nothing after the colon:

```sh
ferry memory                          # notes here
ferry memory ~/develop/acme           # notes there
ferry memory --global                 # every directory that remembers anything
ferry export --memory ~/develop/acme       # those notes, as one document
ferry export --memory ~/develop/acme:role  # or just one of them
ferry export --memory work:acme            # from a store, without loading it
ferry export --memory work:acme/role
```

**`--memory` says which of the two you mean, everywhere.** A store keeps
sessions and memory in separate trees, so nothing has to be inferred from a
path — and a session may be called `memory` like anything else.

**`export` reads from anywhere.** `sync` decides its own direction, but it
always names a place in the store; reading is the same question wherever the
conversation sits, so an export ref can name three things:

```sh
ferry export bug-hunt                     # this directory
ferry export work:acme/bug-hunt           # a store
ferry export ~/develop/acme:bug-hunt      # another directory on this machine
```

What is before the colon decides: a store ferry knows about, or a path. Stores
win, being a closed set of names, so a directory sharing a store's name is
reached as `./work:bug-hunt`. Naming the directory is what makes the third form
safe — session names are unique only within a directory, so a bare name hunted
across the machine would eventually pick the wrong one without saying so.
`ferry sessions --global` lists what there is, with a path for each that is
checked to resolve, and `ferry export <TAB>` offers those directories
alongside the local names and the stores.

What it prints is the conversation: what you asked, what Claude answered, and
one line per tool call. That is about 1% of a transcript — a 17.9 MB session
comes out as 95 KB — because tool results are the bulk of any real session.
`--tools` puts them back, in full. Images cannot go in the text at all, so
they are noted where they appeared, and written out beside it with `--media`.

**A session with no name is not listed by default.** It cannot be named in a
ref — `sync` refuses it and `<dir>:<name>` has nothing to match — so listing it
offers you something you cannot then act on, and completion would walk you into
directories with nothing behind them. `--all` brings them back, addressed by
their full id, which is the only handle they have — with whatever Claude
called the session beside it, since an id says nothing about what it was.
`ferry sessions` says how many are hiding.

**A store is a plain git repo.** ferry only fast-forwards; it never merges.

**The list of stores is a file, written carefully.** It is rewritten by
`add`, `rename` and `remove` — never by anything else — beside itself and
renamed into place, so an interrupted write leaves the old file rather than
half of one. Those three take a lock while they read and change it, so two at
once cannot undo each other; the lock covers the rewrite only, never a clone
or a push, and a second ferry waits a few seconds and then says so rather than
hanging. Memory is replaced the same way: copied alongside and swapped, so
stopping a `sync --memory` part-way leaves the notes you had.

**The registry is a list of names, and only that.** `ferry remove` forgets a
name; it does not delete the checkout, because ferry did not put most of what
is in there and cannot know whether you want it. It tells you where the
directory is, and refuses outright when that directory holds something the
remote has not got — an unpushed sync, uncommitted changes, or no remote at
all — since forgetting the name would turn those into a path you had to
remember. `--force` overrides it. `ferry rename` takes the checkout with it
when ferry made it, and leaves one you adopted where you put it.

## What it protects you from

| | |
|---|---|
| a shorter copy overwriting a longer one | refused — transcripts only grow, so that means lost turns |
| a different session overwriting a name | refused — the id inside the file is checked, not just the path |
| committing transcripts unencrypted | refused unless `--allow-plaintext` |
| overwriting memory that already has notes | refused without `--force` |
| a diverged clone | reported by `update`, which explains the two ways out |

`--force` overrides the first four, when you mean it.

Most flags have a short form — `-m` `--memory`, `-f` `--force`, `-a` `--all`,
`-g` `--global`, `-n` `--name`, `-k` `--key`, `-p` `--path`, `-t` `--tools`,
`-r` `--raw`, `-V` `--version` — and a letter never means two things. That is
why `--media` has none: `-m` is already memory in four commands. Nor does
`--allow-plaintext`, where typing it out is the point.

## How it works

Claude Code stores transcripts in `~/.claude/projects/<slug>/`, where `<slug>`
is the directory's absolute path with every non-alphanumeric character replaced
by `-`, truncated to 200 characters plus a hash if longer. ferry computes the
same name, copies the `.jsonl` out or in, and commits.

In the store, the two kinds live in two trees:

```
sessions/acme/bug-hunt.jsonl     a transcript - the filename is its name
memories/acme/*.md               a directory's memory, as notes
```

You never type `sessions/` or `memories/` — `ferry sync work:acme/bug-hunt`
and `ferry list work` say `acme`, as they always did. The split is there so the
two cannot interfere: memory is written by replacing its directory wholesale,
and in one shared tree that would take any transcript filed beside it with it.
Separate trees make that impossible rather than merely discouraged.

The cost is that `ferry list` no longer matches `git ls-files`; prefix a path
with its tree when working in the checkout by hand. `ferry move` re-files
something and pushes the commit; deleting is still `git rm` there.

`sync` and `move` write to the remote — `sync` only when this machine's copy
is the one holding more. `list`, `export` and `update` never push, and `list`
fetches without merging so it can always show what is really there, even when
your clone has diverged.

## Limitations

- **No merging.** `sync` copies whole, in whichever direction loses nothing.
  When both copies have moved it stops and says so; joining them back up is
  yours to do, for now.
- **Memory is replaced wholesale**, so a note is compared by its name and its
  contents together. A note edited on both machines is a fork, and stops the
  sync rather than being merged.
- **Collisions are caught, not resolved.** ferry stops and tells you.
- **Nothing happens on its own.** No daemon, no watcher, no hook: ferry moves
  exactly what you name, when you name it.
- **git-crypt hides contents, not names.** Directory and file names, sizes and
  commit messages stay readable, so keep the store private.

## Completion

`install.sh` sets this up for you:

```
bash completion -> ~/.local/share/bash-completion/completions/ferry
zsh completion  -> ~/.local/share/zsh/site-functions/_ferry
```

bash picks that up on its own. If `ferry <TAB>` does nothing, your bash is
older than 4.2 and does not search that directory - source the file directly:

```sh
echo ". ~/.local/share/bash-completion/completions/ferry" >> ~/.bash_profile
```

zsh needs the directory on its `fpath`, before `compinit`:

```sh
fpath=(~/.local/share/zsh/site-functions $fpath)
```

Completes commands, each command's flags, store references and session names.
`ferry sync work:<TAB>` walks what the store holds, one level at a time like
filename completion; `ferry export <TAB>` adds the directories that
hold sessions, ready for a name after the colon; and `--memory` changes what is
offered, because it changes which of the store's two trees is being asked
about. `--all` widens the last two to sessions that have no name, offered by
id.

Where a path belongs — the value of `--key` or `--path` — the shell completes
filenames. Where nothing belongs at all, such as after `ferry stores`, nothing
is offered, not even a filename. An empty list cannot tell those two apart, so
`ferry complete` says which by its exit status.

Nothing is offered that would not work. Directories are completed from the
ones that actually hold what the command needs, not from the filesystem, so
TAB cannot walk you into a directory with nothing in it — `ferry export
<TAB>` skips one whose sessions are all unnamed, because there would be no ref
to name them by, while `--all` brings it back since an id is then a handle.

Naming the local sessions means reading each transcript, which sounds slow and
is not - about 0.2s for 60 MB, because the name is on a line that is cheap to
recognise. Names inside the *store* are still not offered: those files are
encrypted, so there is nothing to read without decrypting the lot.

## Telling Claude about it

`skills/ferry/SKILL.md` is a Claude Code skill: it teaches Claude what ferry
can do, so you can ask "which sessions do I have?" or "suggest names for the
unnamed ones" and have it use the tool rather than reading transcripts by
hand — which matters, since a transcript runs to tens of megabytes and
`ferry export` gives you the conversation in about 1% of that.

```sh
curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | FERRY_SKILL=1 sh
```

or, to have it follow a checkout:

```sh
mkdir -p ~/.claude/skills
ln -s "$PWD/skills/ferry" ~/.claude/skills/ferry
```

Opt-in either way. It is not installed for you: `~/.claude` belongs to Claude
Code, and a skill shapes what Claude does in conversations that have nothing to
do with ferry — your decision rather than an installer's.

The skill reads and never writes. It will tell you the `ferry sync` or
`ferry name` command to run, and leave the running to you.

## Contributing

Running the tests and cutting a release are covered in
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
