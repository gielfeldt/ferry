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
    # A folder must not get a space after it, so the next TAB can carry on into
    # it; anything else is a finished word and should move the cursor on.
    local -a folders words
    local c
    for c in $candidates; do
        [[ $c == */ ]] && folders+=($c) || words+=($c)
    done
    (( ${#folders} )) && compadd -S '' -a folders
    (( ${#words} )) && compadd -a words
}
_ferry "$@"
