#compdef ferry ./ferry
# ferry completion for zsh
#   installed to ~/.local/share/zsh/site-functions/_ferry, which must be on fpath
#   the #compdef tag has to be the first line - compinit reads no further
_ferry() {
    local -a candidates
    local raw rc
    # not `status`: zsh keeps that read-only as a synonym for $?, and assigning
    # to it aborts the function before it ever reaches a candidate.
    # The ferry being typed, not whichever is on PATH: `./ferry` in a checkout
    # must answer for itself, or completion describes the installed release
    # while you are running the working copy.
    raw=$(${words[1]:-ferry} complete --line "$BUFFER" 2>/dev/null)
    rc=$?
    # 1: nothing belongs in this position. 2: a path does. Anything else is a
    # list of candidates, which may legitimately be empty.
    (( rc == 1 )) && return 1
    (( rc == 2 )) && { _files; return }
    candidates=(${(f)raw})
    (( ${#candidates} )) || return
    # A candidate you carry on from must not get a space after it: a slash
    # walks into a folder, a colon is a store waiting for a path. Anything
    # else is a finished word and should move the cursor on.
    local -a partial complete
    local c
    for c in $candidates; do
        [[ $c == */ || $c == *: ]] && partial+=($c) || complete+=($c)
    done
    (( ${#partial} )) && compadd -S '' -a partial
    (( ${#complete} )) && compadd -a complete
}
_ferry "$@"
