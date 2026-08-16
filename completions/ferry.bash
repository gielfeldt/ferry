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
complete -o nosort -o nospace -F _ferry ferry
