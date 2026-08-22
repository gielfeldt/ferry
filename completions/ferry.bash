# ferry completion for bash
#   installed to ~/.local/share/bash-completion/completions/ferry
_ferry() {
    local IFS=$'\n' line token head raw status i real self
    line="${COMP_LINE:0:$COMP_POINT}"
    # Ask the ferry being completed - bash passes it as $1 - so `./ferry` in a
    # checkout answers for itself rather than the release describing it. This
    # is how a completion that asks the program itself is usually written; gh,
    # jj, pip and delta all run "$1" the same way.
    #
    # An alias or a shell function cannot be run from a variable: expansion
    # happens after alias expansion, so `f` would simply fail to execute and
    # offer nothing. Anything that will not run falls back to the name on the
    # PATH, which is what an alias almost always points at anyway.
    self=${1:-ferry}
    case $self in
        */*) [ -x "$self" ] || self=ferry ;;
        *) [ -n "$(type -P -- "$self" 2>/dev/null)" ] || self=ferry ;;
    esac
    # Parse the raw line in ferry, not here: bash breaks words on ':' (it is in
    # COMP_WORDBREAKS), which would split "store:personal" into three words.
    raw=$("$self" complete --line "$line" 2>/dev/null)
    status=$?
    token=${line##* }
    COMPREPLY=()

    # 1: nothing belongs here, so offer nothing - not even a filename, which is
    # what `complete -o default` would have done and cannot be switched off per
    # call on bash 3.2. 2: a path belongs here.
    [ $status -eq 1 ] && return
    if [ $status -eq 2 ]; then
        for i in $(compgen -f -- "$token"); do
            real=${i/#\~/$HOME}
            [ -d "$real" ] && i="$i/"
            COMPREPLY+=("$i")
        done
        _ferry_finish
        return
    fi

    COMPREPLY=($raw)
    # bash replaces only the text after the last colon, so hand back just that
    # part or nothing is inserted.
    if [[ $token == *:* ]]; then
        head=${token%"${token##*:}"}
        # Trimmed one element at a time on purpose. bash 3.2 collapses
        # ("${COMPREPLY[@]#"$head"}") into a single space-joined word whenever
        # IFS has no space in it - and readline then inserts that whole word,
        # putting every candidate on the command line at once.
        for ((i = 0; i < ${#COMPREPLY[@]}; i++)); do
            COMPREPLY[i]=${COMPREPLY[i]#"$head"}
        done
    fi
    _ferry_finish
}

# -o nospace is set for the whole command, because a candidate you carry on
# from must not get a space after it. That also suppresses the space on one
# that *is* finished, leaving TAB to redraw the same word forever, so put it
# back here - but only for a word that is actually done.
#
# Two endings mean "keep going": a slash, which walks into a folder, and a
# colon, which is a store waiting for a path after it.
_ferry_finish() {
    [ ${#COMPREPLY[@]} -eq 1 ] || return
    case ${COMPREPLY[0]} in
        */|*:) ;;
        *) COMPREPLY[0]="${COMPREPLY[0]} " ;;
    esac
}
# -o nosort keeps ferry's own ordering, but it is bash 4.4+ and older bash
# rejects the whole command rather than the one option - which would leave
# ferry with no completion at all. Sorted is a fine second best; the candidates
# come back sorted anyway.
# ./ferry as well as ferry: a checkout is run by path, and bash matches the
# word as typed rather than what it resolves to.
complete -o nosort -o nospace -F _ferry ferry ./ferry 2>/dev/null ||
    complete -o nospace -F _ferry ferry ./ferry
