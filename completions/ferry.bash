# ferry completion for bash
#   source /path/to/ferry.bash        (or drop it in /etc/bash_completion.d/)
_ferry() {
    local IFS=$'\n'
    COMPREPLY=($(ferry complete "${COMP_WORDS[@]:0:$((COMP_CWORD+1))}" 2>/dev/null))
}
complete -o nosort -o nospace -F _ferry ferry
