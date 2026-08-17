# ferry completion for zsh
#   installed to ~/.local/share/zsh/site-functions/_ferry, which must be on fpath
#compdef ferry
_ferry() {
    local -a candidates
    candidates=(${(f)"$(ferry complete --line "$BUFFER" 2>/dev/null)"})
    # Nothing to offer means the position takes a path or a name of your own -
    # so hand it to the file completer rather than answering with silence.
    if (( ${#candidates} )); then
        compadd -S '' -a candidates
    else
        _files
    fi
}
_ferry "$@"
