# Contributing to ferry

ferry is one Python file with no dependencies. `ferry` is the program, `test`
is the suite, `completions/` holds the two shell scripts, and `install.sh`
fetches all three from a release.

## Running your copy

`./ferry` runs straight from the checkout. To use it as it will be installed:

```sh
install -m755 ferry ~/.local/bin/ferry
cp completions/ferry.bash ~/.local/share/bash-completion/completions/ferry
cp completions/ferry.zsh  ~/.local/share/zsh/site-functions/_ferry
```

`ferry --version` says `0.0.0+dev` for anything that did not come from a
release, so you can always tell which one you are talking to.

**It targets Python 3.9.** CI runs 3.9, 3.12 and 3.13, and your machine is
almost certainly newer than the floor — so `match`, `X | None` in annotations
and anything else from 3.10 onwards will pass locally and fail on CI.

## Tests

```sh
./test          # everything
./test -v       # with each case named
./test Export   # one class
```

Needs python3, and `bash` for the handful that run the completion script for
real. Nothing else: no network, no git repo, no store, and never your actual
`~/.claude` — anything that would need one builds a temporary copy, and the
few that want a registered store skip when there is none.

What that leaves uncovered is worth knowing: `add`, `save`, `load`, `move`,
`list` and `update` are exercised only as far as their argument parsing, with
the command itself stubbed out. Nothing drives them against a real store, so
bugs in what they actually do to files and git have to be caught by hand.

To drive the untested ones for real, point a throwaway store at a plain git
repo and work from a directory that already has sessions in it:

```sh
mkdir /tmp/store && git -C /tmp/store init -q
git -C /tmp/store commit -q --allow-empty -m init

HOME=/tmp/home ferry add throwaway --path /tmp/store
cd ~/somewhere/with/sessions
ferry save some-session to throwaway:proj --allow-plaintext
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
git tag -a v1.2.14 -m "what changed"
git push origin v1.2.14
```

A workflow runs the tests, writes the tag's version into `ferry`, and
publishes a release carrying `ferry`, `ferry.bash` and `ferry.zsh`. The notes
come from the tag's own message if it is annotated, and from the tagged commit
otherwise.

The version is written down in exactly one place — the tag. In the repo
`__version__` is `0.0.0+dev`, so a copy taken from a checkout says what it is
instead of claiming to be a release, and there is no second place to remember
to bump. Assets are named after their paths in the repo, so they cannot pick
up a different name from however the command was typed that day.

Two things worth doing by hand before tagging, because nothing else will:

- **Install the release afterwards and use it**, rather than testing your
  checkout. A `BrokenPipeError` in `ferry export … | head` shipped in 1.2.11
  and was found by the first command run against the installed build.
- **Try it on a big session.** Output smaller than a pipe buffer never
  exercises a closed pipe, which is exactly how that one got through.

GitHub's `releases/latest/download/` redirect lags a minute or two behind a
new release, so an install immediately after tagging can fetch the previous
one. `install.sh` resolves the version through the API, which settles sooner,
but not instantly.
