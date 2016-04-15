# ~/.bashrc

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
    alias vless=$(rpm -ql vim-common | grep less.sh)
fi


###############################################################################
# BEGIN: Misc functions
yaml2json() {
    python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < $1
}

gen_passwd () {
    if [[ -z $1 ]]; then
        tr -cd '[:graph:]' < /dev/urandom | fold -w30 | head -n1
    else
        tr -cd '[:graph:]' < /dev/urandom | fold -w$1 | head -n1
    fi
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
        git checkout $1
        git fetch upstream
        #git fetch upstream --tags
        git merge upstream/$1
        git push origin $1
        #git push origin --tags
        git checkout ${pullup_startbranch}
    fi
}

pullansible() {
    for i in ${ansible_git_repos[@]}
    do
        pushd ~/src/dev/${i} &> /dev/null
            printf "===== %s =====\n" "$i"
            pullupstream devel
        popd
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
    git log --graph --abbrev-commit --date=relative --pretty="tformat:${_format}" $* |
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
alias gsh='git show --pretty="format:" --name-only'
alias gsl="git stash list"

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
RED='\[\e[0;31m\]'
BRIGHTRED='\[\e[1;31m\]'
GREEN='\[\e[1;32m\]'
ORANGE='\[\e[0;33m\]'
YELLOW='\[\e[1;33m\]'
BLUE='\[\e[1;34m\]'
MAGENTA='\[\e[0;35m\]'
CYAN='\[\e[1;36m\]'
WHITE='\[\e[1;37m\]'
NORMAL='\[\e[0;39m\]'

#Solarized colors
S_RED='\[\e[0;31m\]'
S_GREEN='\[\e[0;32m\]]'
S_ORANGE='\[\e[0;33m\]'
S_BLUE='\[\e[0;34m\]'
S_MAGENTA='\[\e[0;35m\]'
S_CYAN='\[\e[0;36m\]'
S_WHITE='\[\e[0;37m\]'



### UGLY HACK
# This works and the vcs prompt from git bash completion did weird things to
# my PS1 ... meh
__my_vcs_prompt () {
    if [ -x /usr/bin/git ]; then
        if git branch &> /dev/null; then
            printf "($(grep '*' <(git branch) | sed s/\*.//))";
        fi
    fi
}

# Gaming PROMPT_COMMAND and PS1 for multi-line "prompt" with bash/readline
# 'set show-mode-in-prompt on' (requires bash 4.3+ and readline 6.3+)
short_hostname=${HOSTNAME%%.*}
#### YES I KNOW THIS IS "SLOWER" ... shhhhh
if [[ $EUID -ne 0 ]]; then

    # Set laptop colorscheme conditionally
    if [[ ${short_hostname} == "pseudogen" ]]; then
        # New prompt - local colorscheme
        PROMPT_COMMAND='printf "[\e[0;31m$(date +%H:%M:%S)\e[0;39m|\e[0;33m${USER}\e[0;34m@\e[0;33m${short_hostname}\e[0;39m($?)\e[0;31m$(__my_vcs_prompt)\e[1;36m $(if [[ "$PWD" =~ "$HOME"  ]]; then printf "~${PWD#${HOME}}"; else printf $PWD; fi)\e[0;39m]\n"'
    else
        # New prompt - remote colorscheme
        PROMPT_COMMAND='printf "[\e[0;35m$(date +%H:%M:%S)\e[0;39m|\e[0;36m${USER}\e[0;34m@\e[0;36m${short_hostname}\e[0;39m($?)\e[0;31m$(__my_vcs_prompt)\e[0;36m $(if [[ "$PWD" =~ "$HOME"  ]]; then printf "~${PWD#${HOME}}"; else printf $PWD; fi)\e[0;39m]\n"'
    fi
else
    # Set laptop colorscheme conditionally
    if [[ ${short_hostname} == "pseudogen" ]]; then
        # New prompt - local colorscheme
        PROMPT_COMMAND='printf "[\e[0;31m$(date +%H:%M:%S)\e[0;39m|\e[0;31m${USER}\e[0;39m@\e[0;31m${short_hostname}\e[0;39m($?)\e[0;31m$(__my_vcs_prompt)\e[1;39m $(if [[ "$PWD" =~ "$HOME"  ]]; then printf "~${PWD#${HOME}}"; else printf $PWD; fi)\e[0;39m]\n"'
    else
        # New prompt - local colorscheme
        PROMPT_COMMAND='printf "[\e[0;35m$(date +%H:%M:%S)\e[0;39m|\e[0;31m${USER}\e[0;39m@\e[0;36m${short_hostname}\e[0;39m($?)\e[0;31m$(__my_vcs_prompt)\e[1;39m $(if [[ "$PWD" =~ "$HOME"  ]]; then printf "~${PWD#${HOME}}"; else printf $PWD; fi)\e[0;39m]\n"'
    fi
fi
export PROMPT_COMMAND

# OLD PS1 - local colorscheme
## PS1="$NORMAL[$S_RED\t$NORMAL|$S_ORANGE\u$S_BLUE@$S_ORANGE\h$NORMAL(\$?)$S_RED\$(__my_vcs_prompt) $CYAN\w$NORMAL]\$ "

# OLD PS1 - remote colorscheme
#PS1="$NORMAL[$S_MAGENTA\t$NORMAL|$S_CYAN\u$S_BLUE@$S_CYAN\h$NORMAL(\$?)$S_RED\$(__my_vcs_prompt) $S_CYAN\w$NORMAL]\n\$ "

PS1="\$ "
export PS1

# END: PROMPT and PS1 stuff
###############################################################################
