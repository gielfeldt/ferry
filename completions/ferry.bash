# ferry completion for bash
#   installed to ~/.local/share/bash-completion/completions/ferry
_ferry() {
    local IFS=$'\n' line token head
    line="${COMP_LINE:0:$COMP_POINT}"
    # Parse the raw line in ferry, not here: bash breaks words on ':' (it is in
    # COMP_WORDBREAKS), which would split "store:personal" into three words.
    COMPREPLY=($(ferry complete --line "$line" 2>/dev/null))
    # For the same reason bash replaces only the text after the last colon, so
    # hand back just that part or nothing is inserted.
    token="${line##* }"
    if [[ $token == *:* ]]; then
        head="${token%"${token##*:}"}"
        COMPREPLY=("${COMPREPLY[@]#"$head"}")
    fi
}
# -o nosort keeps ferry's own ordering, but it is bash 4.4+ and older bash
# rejects the whole command rather than the one option - macOS still ships 3.2,
# where that would leave ferry with no completion at all. Sorted is a fine
# second best; the candidates come back sorted anyway.
complete -o nosort -o nospace -F _ferry ferry 2>/dev/null ||
    complete -o nospace -F _ferry ferry
