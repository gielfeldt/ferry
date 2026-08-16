# ferry completion for zsh
#   source /path/to/ferry.zsh        (after compinit)
_ferry() {
    local -a candidates
    candidates=(${(f)"$(ferry complete ${words[1,CURRENT]} 2>/dev/null)"})
    compadd -S '' -a candidates
}
compdef _ferry ferry
