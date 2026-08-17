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
claude --resume bug-hunt
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
ferry move <store>:<path> <store>:<dir> [--force]
ferry move --memory <store>:<dir> <store>:<dir> [--force]
ferry list [<store>[:<path>]]
ferry list --memory [<store>[:<dir>]]
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

ferry list work                               # its sessions
ferry list --memory work                      # its memory
ferry list --memory work:acme                 # the notes in one folder
ferry load work:acme/bug-hunt                 # a session
ferry load --memory work:acme                 # that folder's memory
ferry update work                             # pull, and explain a divergence

ferry move work:acme/bug-hunt work:archive    # -> archive/bug-hunt.jsonl
ferry move --memory work:acme work:acme-v2    # -> acme-v2/memory
```

[COOKBOOK.md](COOKBOOK.md) works through the situations you will actually hit.

## Concepts

**Everything is relative to the directory you are standing in.** Claude Code
files transcripts by working directory, so `sessions`, `save` and `load` all act
on the current one. `cd` to where you were working.

**A session is filed under its own name.** `save` takes a *directory* and names
the file after the session, so one conversation has one name on every machine.
The name comes from `/rename`, `/branch` or `claude -n`, and is recorded inside
the transcript — so it travels with the session, and a loaded one answers to it
straight away. A session with no name cannot be saved; there would be nothing to
call it.

**`load` takes a whole path**, because there you are choosing among what the
store holds rather than deciding where something goes.

**`move` re-files, it does not rename.** It takes a path and a directory, and
the leaf goes along unchanged — the same rule `save` follows. A session's name
lives inside its transcript, so a move that could rename the file would let the
two disagree; not being able to say a new name means it cannot happen. To
rename, `/rename` the session and save it again.

**Memory belongs to a directory, not a session.** Claude keeps it in
`memory/*.md` beside the transcripts, shared by everything started there.

**`--memory` says which of the two you mean, everywhere.** A store keeps
sessions and memory in separate trees, so nothing has to be inferred from a
path — and a session may be called `memory` like anything else.

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

In the store, the two kinds live in two trees:

```
sessions/acme/bug-hunt.jsonl     a transcript - the filename is its name
memories/acme/*.md               a directory's memory, as notes
```

You never type `sessions/` or `memories/` — `ferry save bug-hunt to work:acme`
and `ferry list work` say `acme`, as they always did. The split is there so the
two cannot interfere: memory is written by replacing its directory wholesale,
and in one shared tree that would take any transcript filed beside it with it.
Separate trees make that impossible rather than merely discouraged.

The cost is that `ferry list` no longer matches `git ls-files`; prefix a path
with its tree when working in the checkout by hand. `ferry move` re-files
something and pushes the commit; deleting is still `git rm` there.

Only `save` writes to the remote. `load`, `list` and `update` never push, and
`list` fetches without merging so it can always show what is really there,
even when your clone has diverged.

## Limitations

- **Copies, not sync.** Saving replaces the store's copy with yours; loading
  replaces yours with the store's. No merging, and nothing happens on its own.
- **Memory is replaced wholesale**, so notes that exist only on the other
  machine are lost when you save over them. Only notes: transcripts are in
  another tree and cannot be caught by it.
- **Collisions are caught, not resolved.** ferry stops and tells you.
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
`ferry load work:<TAB>` walks what the store holds, one level at a time like
filename completion; `ferry save <TAB>` offers the named sessions in the
directory you are standing in; and `--memory` changes what is offered, because
it changes which of the store's two trees is being asked about.

Naming the local sessions means reading each transcript, which sounds slow and
is not - about 0.2s for 60 MB, because the name is on a line that is cheap to
recognise. Names inside the *store* are still not offered: those files are
encrypted, so there is nothing to read without decrypting the lot.

## Tests

```sh
./test
```

Self-contained: no git, no network, no `~/.claude`. Runs on CI unchanged.

## Releasing

Bump `__version__`, commit, then push a tag:

```sh
git tag v1.2.7
git push origin v1.2.7
```

A workflow does the rest: it refuses the tag if `__version__` disagrees with
it, runs the tests, and publishes a release carrying `ferry`, `ferry.bash` and
`ferry.zsh`. The notes come from the tag's own message if it is annotated, and
from the tagged commit otherwise.

Nothing is uploaded by hand, which is the point — the assets are named after
their paths in the repo, so they cannot pick up a different name from however
the command was typed that day.

## License

[MIT](LICENSE)
