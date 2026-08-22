# Contributing to ferry

ferry is one Python file with no dependencies. `ferry` is the program, `test`
is the suite, `completions/` holds the two shell scripts, and `install.sh`
fetches all three from a release.

## Running your copy

`./ferry` runs straight from the checkout, and needs nothing installed.

To use it everywhere - on `$PATH`, with completion - link it rather than copy
it, so every edit is live and there is no stale copy to forget about:

```sh
ln -sf "$PWD/ferry" ~/.local/bin/ferry
```

`install.sh` will not do this. It fetches the latest **release** from GitHub, so
it installs the last tagged version and knows nothing about your working tree -
which is what you want for a real install and never what you want for testing a
change.

The completion scripts ask whichever ferry you typed - `./ferry <TAB>` in a
checkout answers from the checkout, `ferry <TAB>` from whatever is installed -
so you can compare the two side by side, and completion never describes the
release while you are running your own copy. Both spellings are registered.

They only ever shell out to `<the ferry you typed> complete`, so the link above
covers them; copy them only when you have changed the scripts themselves:

```sh
cp completions/ferry.bash ~/.local/share/bash-completion/completions/ferry
cp completions/ferry.zsh  ~/.local/share/zsh/site-functions/_ferry
```

`ferry --version` says `0.0.0+dev` for anything that did not come from a
release, so you can always tell which one you are talking to. To go back to the
released one:

```sh
rm ~/.local/bin/ferry
curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
```

**It targets Python 3.9.** CI runs 3.9, 3.12 and 3.13, and your machine is
almost certainly newer than the floor — so `match`, `X | None` in annotations
and anything else from 3.10 onwards will pass locally and fail on CI.

## Tests

```sh
./test          # everything
./test -v       # with each case named
./test Export   # one class
```

Run them once against a machine that has nothing:

```sh
HOME=$(mktemp -d) ./test
```

Several tests skip when there is no registered store or no sessions, and it is
easy to write one that quietly depends on yours - it passes for you and fails
on CI, where neither exists, and it has failed a release before now.

Needs python3, and `bash` and `zsh` for the handful that run the completion
scripts for real. Nothing else: no network, no git repo, no store, and never your actual
`~/.claude` — anything that would need one builds a temporary copy, and the
few that want a registered store skip when there is none.

What that leaves uncovered is worth knowing: `add`, `sync`, `move`, `list` and
`update` are exercised only as far as their argument parsing, with the command
itself stubbed out — though `sync`'s decision, which is the part that could
lose work, is covered directly in `Relation` and `LineSet`. Nothing drives the
commands against a real store, so bugs in what they actually do to files and
git have to be caught by hand.

To drive the untested ones for real, point a throwaway store at a plain git
repo and work from a directory that already has sessions in it:

```sh
mkdir /tmp/store && git -C /tmp/store init -q
git -C /tmp/store commit -q --allow-empty -m init

HOME=/tmp/home ferry add throwaway --path /tmp/store
cd ~/somewhere/with/sessions
ferry sync throwaway:proj/some-session --allow-plaintext
ferry list throwaway
ferry export throwaway:proj/some-session | head
```

`--allow-plaintext` is needed because a bare repo has no git-crypt; that is the
one thing this setup does not exercise. Setting `HOME` keeps the store out of
your real config.

Shell behaviour is the other gap that keeps biting. The completion tests run
under **every** bash on the machine rather than the first on `PATH`, because
bash 3.2 and bash 5 disagree about quoting inside a parameter expansion, and
testing only the newer one is how a 3.2 bug ships from a machine where bash 5
comes first.

zsh gets less: a real `compinit` is run over the script to check it registers
against the ferry command, and `zsh -n` parses it, but nothing drives the
candidates through it the way the bash tests do. That much exists because the
script shipped with `#compdef ferry` on line 3 rather than line 1 - compinit
reads the first line and no further - and no test could see it.

## Completion

The Python side generates candidates and the two shell scripts present them.
They agree through the exit status of `ferry complete`, because an empty list
cannot say which kind of nothing it means:

```
0   these candidates (an empty list means no match)
1   nothing belongs here - do not guess, not even a filename
2   a path belongs here - let the shell complete files
```

You can see both without involving a shell, which is much the fastest loop:

```sh
ferry complete --line "ferry export "; echo "exit $?"
```

`--line` takes the raw command line rather than pre-split words, because bash
breaks words on `:` and would hand over `store:personal` in three pieces.

When it does need a shell, drive a real one — the last two completion bugs were
invisible to anything less. Both scripts are also careful about a trailing `/`
or `:`, which mean "keep going" and must not get a space after them.

## Releasing

Push a tag. That is the whole of it:

```sh
git tag -a v1.0.1 -m "what changed"
git push origin v1.0.1
```

A workflow runs the tests, writes the tag's version into `ferry`, and
publishes a release carrying `ferry`, `ferry.bash`, `ferry.zsh` and
`SKILL.md`. The notes
come from the tag's own message if it is annotated, and from the tagged commit
otherwise.

The version is written down in exactly one place — the tag. In the repo
`__version__` is `0.0.0+dev`, so a copy taken from a checkout says what it is
instead of claiming to be a release, and there is no second place to remember
to bump. Assets are named after their paths in the repo, so they cannot pick
up a different name from however the command was typed that day.

Two things worth doing by hand before tagging, because nothing else will:

- **Install the release afterwards and use it**, rather than testing your
  checkout. A `BrokenPipeError` in `ferry export … | head` once shipped in a
  release and was found by the first command run against the installed build.
- **Try it on a big session.** Output smaller than a pipe buffer never
  exercises a closed pipe, which is exactly how that one got through.

GitHub's `releases/latest/download/` redirect lags a minute or two behind a
new release, so an install immediately after tagging can fetch the previous
one. `install.sh` resolves the version through the API, which settles sooner,
but not instantly.
