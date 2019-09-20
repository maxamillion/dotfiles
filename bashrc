#!/bin/bash
# Shebang is for syntastic vim plugin tips
###########################################################################
#~/.bashrc

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


##### History Stuff
shopt -s histappend # append that shit
shopt -s cmdhist # only one cmd per line!
HISTCONTROL=ignoreboth # stop logging duplicates and lines starting with a space
HISTFILESIZE=1000000 # mo lines, mo betta
HISTSIZE=1000000
HISTTIMEFORMAT='%F %T ' # timestamp that shit

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Source private bash bits I don't want on github dotfiles repo
if [ -f ~/.bashrc_private ]; then
    . ~/.bashrc_private
fi

# Source termux bash bits if they exist
if [ -f ~/.bashrc_termux ]; then
    . ~/.bashrc_termux
fi

# Local user install of virtualenvwrapper
if [ -f ~/.local/bin/virtualenvwrapper.sh ]; then
    export WORKON_HOME=${HOME}/.virtualenvs
    export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
    . ~/.local/bin/virtualenvwrapper.sh
fi

# Source bash-completions if available
#   Yes, I know technically this should go in ~/.bash_profile but shhhhh
if ! shopt -oq posix; then
    if [ -f /etc/profile.d/bash_completion.sh ]; then
        . /etc/profile.d/bash_completion.sh
    fi
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
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

# try and thwart pastejacking
# https://lists.gnu.org/archive/html/bug-bash/2019-02/msg00057.html
set enable-bracketed-paste On

export LANG=en_US.UTF-8
export EDITOR=vim

# Make dir completion better
#complete -r cd &> /dev/null
#complete -p cd &> /dev/null
#bind 'TAB:menu-complete'
#bind 'set show-all-if-ambiguous on'

#FIXME - F19+ PROMPT_COMMAND does stupid shit with escape sequences
unset PROMPT_COMMAND

# "Bash aliases you can't live without"
# https://opensource.com/article/19/7/bash-aliases
alias lt='ls --human-readable --size -1 -S --classify'
alias mnt="mount | awk -F' ' '{ printf \"%s\t%s\n\",\$1,\$3; }' | column -t | egrep ^/dev/ | sort"


# Fedora aliases
alias fedpkg="fedpkg --user=maxamillion"
alias fedpkg-stage="fedpkg-stage --user=maxamillion"
alias fek="fedora-easy-karma --fas-username=maxamillion"

# ansible aliases
alias a="ansible"
alias ap="ansible-playbook"

# random/various aliases
alias pj="python -mjson.tool" # prettyjson
alias sharedir='python3 -m http.server'
alias pu='pullupstream'
alias pud='pullupstream devel'
alias pum='pullupstream master'
alias pa='pullansible'
alias ptp='ptpython3'
alias ptp2='ptpython2'
alias ipy='ipython3'
alias ipy2='ipython2'
alias ackp='ack --python'

# kinit aliases
alias kr='kinit admiller@REDHAT.COM'
alias kf='kinit maxamillion@FEDORAPROJECT.ORG'
alias kfs='kinit maxamillion@STG.FEDORAPROJECT.ORG'
alias ksr='kswitch -p admiller@REDHAT.COM'
alias ksf='kswitch -p maxamillion@FEDORAPROJECT.ORG'
alias ksfs='kswitch -p maxamillion@STG.FEDORAPROJECT.ORG'

# ansible dev/test aliases
alias atu='pytest -r a --cov=. --cov-report=html --fulltrace --color yes'
alias atu2='ansible-test units --python 2.7'
alias atu3='ansible-test units --python 3.6'
alias ats2='ansible-test sanity --python 2.7'
alias ats3='ansible-test sanity --python 3.6'

# ssh into cloud instances ignoring warnings and such
alias issh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=QUIET "$@"'

# tmux_sync_env because I'm too lazy to keep typing that shit
alias tse="tmux_sync_env"

# traditional util aliases
alias l.='ls -d .* --color=auto'
alias ll='ls -l --color=auto'
alias ls='ls --color=auto'
alias xzegrep='xzegrep --color=auto'
alias xzfgrep='xzfgrep --color=auto'
alias xzgrep='xzgrep --color=auto'
alias zegrep='zegrep --color=auto'
alias zfgrep='zfgrep --color=auto'
alias zgrep='zgrep --color=auto'

# containers .... docker, podman, whatever is hot next week ....
alias dr='docker run --rm -ti'
alias pr='podman run --rm --net=host -ti'


# update everything in pip
# 100% "borrowed" from stack overflow
#   https://stackoverflow.com/questions/2720014/upgrading-all-packages-with-pip
alias pip2up="pip2 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip2 install -U"
alias pip3up="pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"

if rpm -q vim-common &> /dev/null; then
    alias vless="$(rpm -ql vim-common | grep less.sh)"
fi

# find aliases
alias fn='find . -name'

###############################################################################
# BEGIN: Misc functions

# borrowed from https://development.robinwinslow.uk/2012/07/20/tmux-and-ssh-auto-login-with-ssh-agent-finally/
ssh_agent() {
    # if ssh auth variable is missing
    if [ -z "$SSH_AUTH_SOCK" ]; then
        export SSH_AUTH_SOCK="$HOME/.ssh/.auth_socket"
    fi

    # if socket is available create the new auth session
    if [ ! -S "$SSH_AUTH_SOCK" ]; then
        ssh-agent -a $SSH_AUTH_SOCK > /dev/null 2>&1
        echo $SSH_AGENT_PID > $HOME/.ssh/.auth_pid
    fi

    # if agent isn't defined, recreate it from pid file
    if [ -z $SSH_AGENT_PID ]; then
        export SSH_AGENT_PID=$(cat $HOME/.ssh/.auth_pid)
    fi

    # Add all default keys to ssh auth
    ssh-add 2>/dev/null
}

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

# Sync the environment of an existing shell
#
#  tmux already updates the environment according to
#  the update-environment settings in the config. However
#  for existing shells you need to sync from from tmux's view
#  of the world.
#
# Cribbed from:
#   https://superuser.com/questions/479796/is-it-possible-to-spawn-an-ssh-agent-for-a-new-tmux-session
function tmux_sync_env() {
    ssh_auth_sock=$(tmux showenv | grep "^SSH_AUTH_SOCK")
    ssh_connection=$(tmux showenv | grep "^SSH_CONNECTION")
    export "${ssh_auth_sock}"
    export "${ssh_connection}"
    printf "SSH_AUTH_SOCK and SSH_CONNECTION sync'd\n"
}

# acs-engine stuff
devacs() {
#ACSENGINE_GOPATH="acs-engine"
    export ACSENGINE_ROOT="~/go/src/github.com/Azure/acs-engine"
    export GOPATH=~/go/
    export PATH=$PATH:${GOPATH}/bin
    export PATH=$PATH:${ACSENGINE_ROOT}/bin
    alias cba="cd $ACSENGINE_ROOT"
}

# User specific environment and startup programs
proxy () {
    if [[ -z "$1" ]]; then
        export http_proxy='http://file.rdu.redhat.com:3128';
        export https_proxy='https://file.rdu.redhat.com:3128';
        export HTTP_PROXY='http://file.rdu.redhat.com:3128';
        export HTTPS_PROXY='https://file.rdu.redhat.com:3128';
    else
        export http_proxy="$1";
        export https_proxy="$1";
        export HTTP_PROXY="$1";
        export HTTPS_PROXY="$1";
    fi
}

unproxy() {
    unset http_proxy;
    unset https_proxy;
    unset HTTP_PROXY;
    unset HTTPS_PROXY;
}

# Get SELinux Python bindings symlink'd into the local python venv
sevenv() {
    local py_path=$(which python)
    if ! [[ ${py_path} =~ 'virtualenv' ]]; then
        printf "NOT IN A VIRTUALENV!\n"
        return 1
    fi

    local py_version=$(python -c 'import platform; print(platform.python_version());')
    local py_shortver="${py_version%*.*}"
    local pylib64_path="/usr/lib64/python${py_shortver}/site-packages/"
    if ! [[ -d "${pylib64_path}" ]]; then
        printf "${pylib64_path} doesn't exist, check host python version!\n"
        return 1
    fi


    local venv_basepath="${py_path%*/*/*}"
    ln -s "${pylib64_path}/selinux/" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/selinux"
    ln -s "${pylib64_path}/semanage.py" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/semanage.py"
    local selinux_so=$(find "${pylib64_path}" -name _selinux*.so)
    ln -s "${selinux_so}" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/${selinux_so##*/}"
    local semanage_so=$(find "${pylib64_path}" -name _semanage*.so)
    ln -s "${semanage_so}" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/${semanage_so##*/}"
    printf "DONE!\n"
}


# END: Misc functions
###############################################################################

###############################################################################
# BEGIN: Ansible hacking functions

# "Globals" for Ansible hacking functions
ansible_dev_dir="~/src/dev/ansible/"

# Expand the tilda
eval ansible_dev_dir=${ansible_dev_dir}

ahack() {
    if [[ -d ${ansible_dev_dir} ]]; then
        pushd ${ansible_dev_dir}
            make clean
            source hacking/env-setup
        popd
    else
        printf "ERROR: Ansible dev dir not found: ${ansible_dev_dir}\n"
    fi
}

aclean() {
    if [[ -d ${ansible_dev_dir} ]]; then
        pushd ${ansible_dev_dir}
            make clean
        popd
    else
        printf "ERROR: Ansible dev dir not found: ${ansible_dev_dir}\n"
    fi
}

ardebug(){
    if [[ -d ~/.ansible/tmp ]]; then
        ardebug_dirs=( $(ls ~/.ansible/tmp) )
        pushd ~/.ansible/tmp/${ardebug_dirs[-1]}
            python *.py explode && cd debug_dir
    else
        printf "ERROR: Ansible KEEP_REMOTE_FILES dir not found"
    fi
}

atest(){
    workon ansible # Set the virtualenv via virtualenv-wrappers
    ahack # set the dev env

    ansible-test sanity \
        --color -v --junit --changed --docker --docker-keep-git \
        --base-branch origin/devel --skip-test pylint "${@}"

    aclean # clean the dev env
}


# END: Ansible hacking functions
###############################################################################



###############################################################################
# BEGIN: Git helpers
grabpr () {
    git fetch upstream pull/$1/head:pr/$1 && git checkout pr/$1
}

pullupstream () {
    if [[ -z "$1" ]]; then
        printf "Error: must specify a branch name (e.g. - master, devel)\n"
    else
        pullup_startbranch=$(printf "%s" "$(grep '\*' <(git branch) | sed s/\*.//)")
        git checkout "$1"
        git fetch upstream
        #git fetch upstream --tags
        git merge "upstream/$1"
        git push origin "$1"
        #git push origin --tags
        git checkout "${pullup_startbranch}"
    fi
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

_hash="%C(bold blue)%h%C(reset)"
_time="%C(bold cyan)%aD%C(reset)"
_relative_time="%C(bold green)(%ar)%C(reset)"
_subject="%C(white)%s%C(reset)"
_author="%C(dim white)- %an%C(reset)"
_refs="%C(bold yellow)%d%C(reset)"

_format="${_hash} - ${_relative_time} ${_subject} ${_author}${_refs}"

pretty_git_log() {
    # For whatever reason appending an empty string onto git causes a change in
    # format so we need a conditional
    if [[ -n "$*" ]]; then
        git log --graph \
            --abbrev-commit \
            --decorate \
            --all \
            --format=format:"${_format}" "$*"
    else
        git log --graph \
            --abbrev-commit \
            --decorate \
            --all \
            --format=format:"${_format}"
    fi
}

show_git_head() {
    pretty_git_log "-1" && \
        git --no-pager show -p --pretty="tformat:"
}

git_auto_bisect(){
    bad_branch=${1}
    good_branch=${2}
    reverse=${3}

    if [[ ${1} == "-h" ]] || [[ -z "${1}" ]]; then
        printf "git_auto_bisect bad_branch good_branch [reverse]\n"
    fi

    if [[ -z "${bad_branch}" ]] || [[ -z "${good_branch}" ]] ; then
        printf "Test command can not be empty\n"
        return 1
    fi

    read -p "Test command: " test_command
    if [[ -z "${test_command}" ]]; then
        printf "Test command can not be empty\n"
        return 1
    fi

    workon ansible
    if [[ "$?" -ne "0" ]]; then
        printf "No virtualenv named ansible3.\n"
        return 1
    fi
    ahack # clean the env
    workon ansible

    git bisect start ${bad_branch} ${good_branch}

    if [[ -z "${reverse}" ]]; then
        eval "git bisect run ${test_command}"
    else
        eval "git bisect run bash -c '! ${test_command}'"
    fi
    git bisect reset

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
alias gab="git_auto_bisect"
alias gph="git push"
alias gpl="git pull"
alias gpr="git pull --rebase"
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
    __git_complete gpr  _git_pull
    __git_complete gs   _git_status
    __git_complete gsl  _git_stash
fi

# END Git helpers
###############################################################################

###############################################################################
# BEGIN Modify PATH

# Functions to help us manage paths.  Second argument is the name of the
# path variable to be modified (default: PATH)
#
# 100% shamelessly "borrowed" from stackoverflow
# https://stackoverflow.com/questions/11650840/linux-remove-redundant-paths-from-path-variable
pathremove () {
        local IFS=':'
        local NEWPATH
        local DIR
        local PATHVARIABLE=${2:-PATH}
        for DIR in ${!PATHVARIABLE} ; do
                if [ "$DIR" != "$1" ] ; then
                  NEWPATH=${NEWPATH:+$NEWPATH:}$DIR
                fi
        done
        export $PATHVARIABLE="$NEWPATH"
}
pathprepend () {
        pathremove $1 $2
        local PATHVARIABLE=${2:-PATH}
        export $PATHVARIABLE="$1${!PATHVARIABLE:+:${!PATHVARIABLE}}"
}

pathappend () {
        pathremove $1 $2
        local PATHVARIABLE=${2:-PATH}
        export $PATHVARIABLE="${!PATHVARIABLE:+${!PATHVARIABLE}:}$1"
}

export GOPATH=$HOME/go
pathappend $GOPATH/bin
pathappend $HOME/node_modules/.bin
pathappend $HOME/bin
pathappend $HOME/.local/bin

# END Modify PATH
###############################################################################


###############################################################################
# BEGIN: PROMPT and PS1 stuff

# local hostnames for my machines to set local PS1 colorscheme vs remote
_localhosts=("mobilegen" "penguin" "localhost")
short_hostname=${HOSTNAME%%.*}

### UGLY HACK
# This works and the vcs prompt from git bash completion did weird things to
# my PS1 ... meh
__my_vcs_prompt () {
    if which git &> /dev/null; then
        if git branch &> /dev/null; then
            printf "(%s)" "$(grep '\*' <(git branch) | sed s/\*.//)";
        fi
    fi
}

# Gaming PROMPT_COMMAND and PS1 for multi-line "prompt" with bash/readline
# 'set show-mode-in-prompt on' (requires bash 4.3+ and readline 6.3+)
__prompt_command() {
    local exit_code=$? # THIS IS ALWAYS FIRST

    history -a # append to the history on the fly for ... $reasons

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
            local host_c=$teal_c
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
            local host_c=$teal_c
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

# FIXME - This is kind of a hack, will fail me in the future
#   In bash 4.4.x the $ is colorized via vi mode-string in ~/.inputrc so it's
#   not needed here.
if [[ $BASH_VERSION =~ 4.4.* ]] || [[ $BASH_VERSION =~ 5.* ]] ; then
    PS1=" "
else
    PS1="\$ "
fi

export PS1

# END: PROMPT and PS1 stuff
###############################################################################
