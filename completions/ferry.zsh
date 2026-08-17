# ferry completion for zsh
#   installed to ~/.local/share/zsh/site-functions/_ferry, which must be on fpath
#compdef ferry
_ferry() {
    local -a candidates
    local raw status
    raw=$(ferry complete --line "$BUFFER" 2>/dev/null)
    status=$?
    # 1: nothing belongs in this position. 2: a path does. Anything else is a
    # list of candidates, which may legitimately be empty.
    (( status == 1 )) && return 1
    (( status == 2 )) && { _files; return }
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
