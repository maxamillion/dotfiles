#!/bin/bash
# Shebang is for syntastic vim plugin tips
###########################################################################
#~/.bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Source private bash bits I don't want on github dotfiles repo
if [ -f ~/.bashrc_private ]; then
    . ~/.bashrc_private
fi

# Source bash-completions if available
#   Yes, I know technically this should go in ~/.bash_profile but shhhhh
if [ -f /etc/profile.d/bash_completion.sh ]; then
    . /etc/profile.d/bash_completion.sh
fi

# various reasons
if [[ -n "$TMUX" ]]; then
    export TERM=screen-256color
    alias man='TERM=xterm man'
    alias less='TERM=xterm less'
fi
if [[ -n "$STY" ]]; then
    export TERM=screen-256color
fi

# vi mode because I'm not a fucking heathen
set -o vi
bind '"\e.":yank-last-arg'

# local hostnames for my machines to set local PS1 colorscheme vs remote
_localhosts=("pseudogen" "stream")

export EDITOR=vim

# Make dir completion better
#complete -r cd &> /dev/null
#complete -p cd &> /dev/null
#bind 'TAB:menu-complete'
#bind 'set show-all-if-ambiguous on'

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$HOME/node_modules/.bin

#FIXME - F19+ PROMPT_COMMAND does stupid shit with escape sequences
unset PROMPT_COMMAND

alias fedpkg="fedpkg --user=maxamillion"

alias fek="fedora-easy-karma --fas-username=maxamillion"

alias prettyjson="python -mjson.tool"

alias sharedir='python -m SimpleHTTPServer'

if rpm -q vim-common &> /dev/null; then
    alias vless="$(rpm -ql vim-common | grep less.sh)"
fi

# Ensure gpg-agent starts with --enable-ssh-support
if [[ $EUID -ne 0 ]]; then
    if [[ ! -f /run/user/$(id -u)/gpg-agent.env ]]; then
        killall gpg-agent &> /dev/null;
        eval $( \
            gpg-agent \
                --daemon \
                --enable-ssh-support \
                > /run/user/$(id -u)/gpg-agent.env
        )
    fi
fi
. /run/user/$(id -u)/gpg-agent.env


###############################################################################
# BEGIN: Misc functions
yaml2json() {
    python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < "$1"
}

gen_passwd () {
    if [[ -z $1 ]]; then
        tr -cd '[:graph:]' < /dev/urandom | fold -w30 | head -n1
    else
        tr -cd '[:graph:]' < /dev/urandom | fold -w"$1" | head -n1
    fi
}
cleandocker() {
    # Clean exited containers
    for container in $(docker ps -a | awk '/Exited/{ print $1}')
    do
        docker rm $container
    done

    # Clean dangling images
    for i in $(docker images -f 'dangling=true' -q)
    do
        docker rmi $i
    done
}
# END: Misc functions
###############################################################################



###############################################################################
# BEGIN: Git helpers
ansible_git_repos=( "ansible" "ansible-modules-core" "ansible-modules-extras" )
alias ansidev='export ANSIBLE_LIBRARY=${HOME}/src/dev/ansible-modules-core:${HOME}/src/dev/ansible-modules-extras'

pullupstream () {
    if [[ -z "$1" ]]; then
        printf "Error: must specify a branch name (e.g. - master, devel)\n"
    else
        pullup_startbranch=$(git describe --contains --all HEAD)
        git checkout "$1"
        git fetch upstream
        #git fetch upstream --tags
        git merge "upstream/$1"
        git push origin "$1"
        #git push origin --tags
        git checkout "${pullup_startbranch}"
    fi
}

pullansible() {
    for i in "${ansible_git_repos[@]}"
    do
        pushd ~/src/dev/"${i}" &> /dev/null
            printf "===== %s =====\n" "$i"
            pullupstream devel
        popd
    done
}

# 'git gc' on all src repos in my homedir
gceverything() {
    for dir in ~/src/*;
    do
        if [[ "$(basename ${dir})" != 'dev' ]]
        then
            pushd ${dir}
                git gc
            popd &> /dev/null
        fi
    done

    for dir in ~/src/dev/*;
    do
        pushd ${dir}
            git gc
        popd &> /dev/null
    done
}

#
# pretty_git_log and show_git_head are both shamelessly lifted from threebean's
# lightsaber repo:
#   https://github.com/ralphbean/lightsaber
_hash="%C(yellow)%h%Creset"
_relative_time="%Cgreen(%ar)%Creset"
_author="%C(bold blue)<%an>%Creset"
_refs="%C(red)%d%Creset"
_subject="%s"

_format="${_hash}}${_relative_time}}${_author}}${_refs} ${_subject}"

pretty_git_log() {
    git log --graph --abbrev-commit --date=relative --pretty="tformat:${_format}" "$*" |
        # Repalce (2 years ago) with (2 years)
        #sed -Ee 's/(^[^<]*) ago)/\1)/' |
        # Replace (2 years, 5 months) with (2 years)
        #sed -Ee 's/(^[^<]*), [[:digit:]]+ .*months?)/\1)/' |
        # Line columns up based on } delimiter
        column -s '}' -t |
        # Page only if we need to
        less -FXRS
}

show_git_head() {
    pretty_git_log -1
    git show -p --pretty="tformat:"
}

# Various aliases
alias g="git"
alias ga="git add"
alias gb="git branch -v"
alias gc="git commit -s"
alias gca="git commit --amend"
alias gcm="git commit -m"
alias gco="git checkout"
alias gd="git diff"
alias gf="git fetch"
alias gfa="git fetch --all"
alias gfp="git format-patch"
alias gfph="git format-patch HEAD~1"
alias gg="git grep -n"
alias gl="pretty_git_log"
alias gh="show_git_head"
alias gph="git push"
alias gpl="git pull"
alias gs="git status -sb"
alias gsh="git show --pretty='format:' --name-only"
alias gsl="git stash list"
alias gho="git hash-object"
alias gcf="git cat-file"

# setup bash completion for the alias (if available)
if [[ -f /usr/share/bash-completion/completions/git ]]; then
    . /usr/share/bash-completion/completions/git
    __git_complete g    __git_main
    __git_complete ga   _git_add
    __git_complete gb   _git_branch
    __git_complete gc   _git_commit
    __git_complete gca  _git_commit
    __git_complete gcm  _git_commit
    __git_complete gco  _git_checkout
    __git_complete gd   _git_diff
    __git_complete gf   _git_fetch
    __git_complete gfa  _git_fetch
    __git_complete gfp  _git_format_patch
    __git_complete gg   _git_grep
    __git_complete gph  _git_push
    __git_complete gpl  _git_pull
    __git_complete gs   _git_status
    __git_complete gsl  _git_stash
fi

# END Git helpers
###############################################################################


###############################################################################
# BEGIN: PROMPT and PS1 stuff



### UGLY HACK
# This works and the vcs prompt from git bash completion did weird things to
# my PS1 ... meh
__my_vcs_prompt () {
    if [ -x /usr/bin/git ]; then
        if git branch &> /dev/null; then
            printf "(%s)" "$(grep '\*' <(git branch) | sed s/\*.//)";
        fi
    fi
}

# Gaming PROMPT_COMMAND and PS1 for multi-line "prompt" with bash/readline
# 'set show-mode-in-prompt on' (requires bash 4.3+ and readline 6.3+)
__prompt_command() {
    local exit_code=$?

    local short_hostname=${HOSTNAME%%.*}

    local prompt_out=""

    # colors
    local red_c='\e[0;31m'
    local white_c='\e[0m'
    local yellow_c='\e[0;33m'
    local blue_c='\e[0;34m'
    local teal_c='\e[1;36m'
    local cyan_c='\e[0;36m'
    local purple_c='\e[0;35m'

    local normal_c=$white_c
    #### YES I KNOW THIS IS "SLOWER" ... shhhhh
    if [[ $EUID -ne 0 ]]; then

        # Set local colorscheme conditionally
        if [[ ${_localhosts[@]} =~ ${short_hostname} ]]; then
            # non-root prompt - local colorscheme
            local date_c=$red_c
            local user_c=$yellow_c
            local at_c=$blue_c
            local host_c=$yellow_c
            local exit_c=$white_c
            local vcs_c=$red_c
            local pwd_c=$teal_c
        else
            # non-root prompt - remote colorscheme
            local date_c=$purple_c
            local user_c=$cyan_c
            local at_c=$blue_c
            local host_c=$cyan_c
            local exit_c=$white_c
            local vcs_c=$red_c
            local pwd_c=$cyan_c
        fi
    else
        # Set local colorscheme conditionally
        if [[ ${_localhosts[@]} =~ ${short_hostname} ]]; then
            # root prompt - local colorscheme
            local date_c=$red_c
            local user_c=$red_c
            local at_c=$white_c
            local host_c=$red_c
            local exit_c=$white_c
            local vcs_c=$red_c
            local pwd_c=$white_c
        else
            # root prompt - remote colorscheme
            local date_c=$purple_c
            local user_c=$red_c
            local at_c=$blue_c
            local host_c=$cyan_c
            local exit_c=$white_c
            local vcs_c=$red_c
            local pwd_c=$white_c
        fi

    fi

    prompt_out+="$normal_c"
    prompt_out+="["
    prompt_out+="$date_c"
    prompt_out+="%(%H:%M:%S)T"
    prompt_out+="$normal_c"
    prompt_out+="|"
    prompt_out+="$user_c"
    prompt_out+="${USER}"
    prompt_out+="$at_c"
    prompt_out+="@"
    prompt_out+="$host_c"
    prompt_out+="${short_hostname}"
    prompt_out+="$exit_c"
    prompt_out+="(${exit_code})"
    prompt_out+="$vcs_c"
    prompt_out+="$(__my_vcs_prompt)"
    prompt_out+="$pwd_c"
    if [[ $PWD =~ $HOME ]]; then
        prompt_out+=" ~${PWD#${HOME}}"
    else
        prompt_out+=" $PWD"
    fi
    prompt_out+="$normal_c"
    prompt_out+="]"

    printf "$prompt_out\n" -1

    return $exit_code
}


export PROMPT_COMMAND=__prompt_command

PS1="\$ "
export PS1

# END: PROMPT and PS1 stuff
###############################################################################
