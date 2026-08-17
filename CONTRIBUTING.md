# Contributing to ferry

ferry is one Python file with no dependencies. `ferry` is the program, `test`
is the suite, `completions/` holds the two shell scripts, and `install.sh`
fetches all three from a release.

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

Shell behaviour is the other gap that keeps biting. The completion tests run
under **every** bash on the machine rather than the first on `PATH`, because
bash 3.2 and bash 5 disagree about quoting inside a parameter expansion, and
testing only the newer one is how a 3.2 bug ships from a machine where bash 5
comes first.

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
