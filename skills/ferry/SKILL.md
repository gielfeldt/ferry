---
name: ferry
description: Find, read and account for Claude Code sessions and memory on this machine or in a ferry store. Use when the user asks which sessions exist, where a past conversation went, what an old session was about, whether something was saved, what a directory remembers, or asks for names for unnamed sessions. Also use when they mention ferry, a store, a transcript, or a session id.
tools: Bash, Read
---

# ferry

`ferry` carries Claude Code sessions and memory between machines through an
encrypted git repo, and reads what is on this one. It is a single command; run
`ferry` with no arguments for its usage.

**Read freely. Never change anything without being asked in this
conversation.** Reading is `sessions`, `memory`, `list`, `export`, `stores`.
Everything else — `sync`, `move`, `name`, `add`, `rename`, `remove` —
alters a transcript, a store or the registry. Propose the exact command and let
the user run it, or run it only after they say yes to that specific command.

## Refs

A ref names one thing. There are three shapes, and the colon says which:

    bug-hunt                      a session in the current directory
    work:acme/bug-hunt            a session in a store
    ~/develop/acme:bug-hunt       a session in another directory here

Session names are unique **within a directory** and nowhere wider, so anything
outside the current directory needs the directory in the ref. A session may
also be named by an id prefix: `~/develop/acme:6af148fd`.

Memory belongs to a directory rather than a conversation, so a memory ref is a
directory, optionally with one note:

    ferry export --memory ~/develop/acme
    ferry export --memory ~/develop/acme:role
    ferry export --memory work:acme/role

## Finding things

    ferry sessions                what is in this directory
    ferry sessions <dir>          another directory
    ferry sessions --global       every named session, with the directory each
                                  belongs to
    ferry sessions --global --all unnamed ones too, by id, with the title
                                  Claude gave them marked *
    ferry memory --global         every directory that remembers anything
    ferry list <store>            what a store holds

Every path `--global` prints is one a ref can use; a session that changed
directory mid-run is listed under the directory its transcript is filed in.

## Reading a session

**Do not read a transcript directly.** They reach tens of megabytes, and
`cat`, `grep` and `Read` over one will waste the context or fail outright. Use:

    ferry export <ref>            the conversation as markdown - what was
                                  asked, what was answered, one line per tool
                                  call. Roughly 1% of the file
    ferry export <ref> --tools    the full tool calls and their output, which
                                  is most of the bytes. Only when what the
                                  tools did is the question
    ferry export <ref> --raw      the transcript itself, byte for byte

Pipe it: `ferry export <ref> | head -100`. `export` reads from the current
directory, another directory, or a store, without loading anything.

## Suggesting names for unnamed sessions

A session with no name cannot be saved, and is not listed without `--all`. To
propose names:

1. `ferry sessions --global --all` — the unnamed ones show as ids with the
   title Claude gave them, marked `*`. That title is often enough.
2. For any whose title says nothing, read a little: `ferry export <ref> | head -80`.
3. Propose a short kebab-case name for each, with the ref beside it, in one
   list.
4. **Stop there.** The user applies them:

       ferry name <ref> <name>

   Offer the commands ready to paste. Do not run them. `ferry name` appends to
   a transcript, and a name is the user's word for their own conversation.

A name must be unique in its directory, cannot hold `/` or `:`, and cannot
begin with `.` or `-`.

## Checking what is in a store

    ferry list <store>            sessions in a store
    ferry list --memory <store>   the memory it holds
    ferry stores                  which stores are registered here

To answer "is this saved?", compare `ferry sessions` here against
`ferry list <store>` — matching by name, since a session keeps one name
everywhere. If it is not there, say so and give the `ferry sync` command that
would send it; do not run it.

`ferry sync <store>:<dir>/<name>` is the one command either way: it compares
the two copies and copies whichever holds more, so the same line works on
either machine. It refuses when both have changed. Never run it to "just
check" — it writes and pushes when this machine is the one that is ahead.
