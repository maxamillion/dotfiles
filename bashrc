#!/bin/bash
# Shebang is for syntastic vim plugin tips
###########################################################################
#~/.bashrc

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Set PAGER
PAGER=less
export PAGER

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

if [ -x /usr/bin/fzf ]; then
    # Set up fzf key bindings and fuzzy completion
    eval "$(fzf --bash)" 
fi

# Handle my hosts for shortnames of things in my homelab
if [ -f ~/.myhosts ]; then
    export HOSTALIASES="${HOME}/.myhosts"
fi

# Local user install of virtualenvwrapper
if [ -f ~/.local/bin/virtualenvwrapper.sh ]; then
    if [ -f /usr/bin/python3 ]; then
        export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
    else
        export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
    fi
    export WORKON_HOME=${HOME}/.virtualenvs
    # shellcheck source=/dev/null
    . ~/.local/bin/virtualenvwrapper.sh
elif [ -f /usr/share/virtualenvwrapper/virtualenvwrapper.sh ]; then
    # shellcheck source=/dev/null
    . /usr/share/virtualenvwrapper/virtualenvwrapper.sh
fi

# Alias podman-compose because fuck docker
if [ -f ~/.local/bin/podman-compose ]; then
    alias docker-compose='podman-compose'
fi

if ! [ -f "/usr/share/bash-completion/completions/pipx.bash" ] && ! [ -f "${HOME}/.local/share/bash-completion/completions/pipx" ]; then
    if [ -f /usr/bin/pipx ]; then
        if [ -f /usr/bin/register-python-argcomplete ]; then
            register-python-argcomplete pipx > "${HOME}/.local/share/bash-completion/completions/pipx"
        fi
    fi
fi

# Only use docker in crostini
if [ -f /usr/bin/dpkg ] && dpkg -l cros-logging > /dev/null 2>&1; then
    export container_runtime='docker'
else
    export container_runtime='podman' # default
fi

# OpenShift/k8s stuff - I typically install these to ~/bin/ for personal sanity
if [ -f ~/.local/bin/oc ]; then
    if ! [ -f "${HOME}/.local/share/bash-completion/completions/oc" ]; then
        "${HOME}/.local/bin/oc" completion bash > "${HOME}/.local/share/bash-completion/completions/oc"
    fi
fi
if [ -f ~/.local/bin/crc ]; then
    if ! [ -f "${HOME}/.local/share/bash-completion/completions/crc" ]; then
        "${HOME}/.local/bin/crc" completion bash > "${HOME}/.local/share/bash-completion/completions/crc"
    fi
fi
if [ -f ~/.local/bin/openshift-install ]; then
    if ! [ -f "${HOME}/.local/share/bash-completion/completions/openshift-install" ]; then
        "${HOME}/.local/bin/openshift-install" completion bash > "${HOME}/.local/share/bash-completion/completions/openshift-install"
    fi
fi

# rustup
if [ -f ~/.cargo/env ]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
fi
if [ -f ~/.cargo/bin/rustup ]; then
    # shellcheck source=/dev/null
    source <(~/.cargo/bin/rustup completions bash cargo)
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
        # shellcheck source=/dev/null
        . /etc/bash_completion
    fi
    if [ -f ~/.local/poetry.bash-completion ]; then
        # shellcheck source=/dev/null
        . ~/.local/poetry.bash-completion
    fi
    if [ -f ~/.local/bin/pipx ]; then
        eval "$(register-python-argcomplete pipx)"
    fi
fi


# various reasons
#if [[ -n "$TMUX" ]]; then
#    export TERM=screen-256color
#    alias man='TERM=xterm man'
#    alias less='TERM=xterm less'
#fi
#if [[ -n "$STY" ]]; then
#    export TERM=screen-256color
#fi

# deal with tmux ssh agent forwarding on remote systems
if [[ -n "${SSH_CONNECTION}" || -n "${SSH_CLIENT}" || -n "${SSH_TTY}" ]]; then
    # From the following blog post to fix ssh agent forwarding with tmux
    # sessions, but do it all in bashrc for simplicity and not fuck with
    # xauth in ~/.ssh/rc
    #
    # https://werat.dev/blog/happy-ssh-agent-forwarding/

    # Modify the symlink no matter what
    if [[ -S "${SSH_AUTH_SOCK}" ]]; then
        ln -sf "${SSH_AUTH_SOCK}" ~/.ssh/ssh_auth_sock
    fi

    # DO NOT to modify the symlink if current is still alive
    #if [ ! -S ~/.ssh/ssh_auth_sock ] && [ -S "$SSH_AUTH_SOCK" ]; then
    #    ln -sf $SSH_AUTH_SOCK ~/.ssh/ssh_auth_sock
    #fi
    export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
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

# NEOVIM STUB
# # neovim 
# if [[ -f /usr/bin/nvim ]] || [[ -f ~/.local/bin/nvim ]]; then
#     alias nv=nvim
#     alias vim=nvim
#     export EDITOR=nvim
# fi

# "Bash aliases you can't live without"
# https://opensource.com/article/19/7/bash-aliases

# Fucking docker ....
alias cruntime="${container_runtime}"

# Fedora aliases
alias fedpkg="fedpkg --user=maxamillion"
alias fedpkg-stage="fedpkg-stage --user=maxamillion"
alias fek="fedora-easy-karma --fas-username=maxamillion"

# ansible aliases
alias a="ansible"
alias ap="ansible-playbook"

# random/various aliases
alias pj="python3 -mjson.tool" # prettyjson
alias sharedir='python3 -m http.server'
alias pu='pullupstream'
alias pud='pullupstream devel'
alias pum='pullupstream master'
alias pa='pullansible'
alias ipy='ipython --TerminalInteractiveShell.editing_mode=vi'
alias ackp='ack --python'

# kinit aliases
alias kr='kinit admiller@REDHAT.COM'
alias kf='fkinit maxamillion@FEDORAPROJECT.ORG'
alias kfs='fkinit maxamillion@STG.FEDORAPROJECT.ORG'
alias ksr='kswitch -p admiller@REDHAT.COM'
alias ksf='kswitch -p maxamillion@FEDORAPROJECT.ORG'
alias ksfs='kswitch -p maxamillion@STG.FEDORAPROJECT.ORG'

# ansible dev/test aliases
alias alintc='cruntime run --rm -t --workdir $(pwd) -v $(pwd):$(pwd) quay.io/ansible/creator-ee ansible-lint --exclude changelogs/ --profile=production'

# ssh into cloud instances ignoring warnings and such
alias issh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

# Go back to allowing keyring daemon to manage this ... for now
## start ssh agent (if necessary)
#alias ssa='ssh_agent'

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

# containers .... 
alias pr='cruntime run --rm -ti'
alias mk='minikube kubectl --'

# toolbox enter
alias te='toolbox enter'

# update everything in pip
# 100% "borrowed" from stack overflow
#   https://stackoverflow.com/questions/2720014/upgrading-all-packages-with-pip
alias pipuup="pip list --user --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 2  | xargs -n1 pip install --user -U"

if rpm -q vim-common &> /dev/null; then
    # shellcheck disable=SC2139
    alias vless="$(rpm -ql vim-common | grep less.sh)"
fi

# find aliases
alias fn='find . -name'

# hexdump with od
alias hexd='od -A x -t x1z -v'

###############################################################################
# BEGIN: Misc functions

# Go back to allowing keyring daemon to manage this ... for now
#export SSH_AUTH_SOCK="$HOME/.ssh/.auth_socket"
#ssh_agent() {
#    rm -f ${SSH_AUTH_SOCK}
#    # if socket is available create the new auth session
#    SSH_AGENT_PID=$(ssh-agent -a ${SSH_AUTH_SOCK} > /dev/null 2>&1)
#    # Add all default keys to ssh auth
#    ssh-add 2>/dev/null
#}

yaml2json() {
    python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < "$1"
}

rhtclaude() {
    # ANTHROPIC_MODEL='claude-sonnet-4@20250514'
    # ANTHROPIC_SMALL_FAST_MODEL='claude-sonnet-4@20250514'
    CLAUDE_CODE_USE_VERTEX=1 \
    CLOUD_ML_REGION=us-east5 \
    ANTHROPIC_VERTEX_PROJECT_ID=itpc-gcp-ai-eng-claude \
    claude "$@"
}

cleancontainers() {
    # Clean exited containers
    for container in $(cruntime ps -a | awk '/Exited/{ print $1}')
    do
        cruntime rm "${container}"
    done

    # Clean dangling images
    for i in $(cruntime images -f 'dangling=true' -q)
    do
        cruntime rmi "${i}"
    done
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

stageproxy () {
    export http_proxy='http://squid.corp.redhat.com:3128';
    export https_proxy='http://squid.corp.redhat.com:3128';
    export HTTP_PROXY='http://squid.corp.redhat.com:3128';
    export HTTPS_PROXY='https://squid.corp.redhat.com:3128';
}

unproxy() {
    unset http_proxy;
    unset https_proxy;
    unset HTTP_PROXY;
    unset HTTPS_PROXY;
}

fn_conditionally_symlink() {
    # function signature:
    #   fn_conditionally_symlink src_path dest_path
    if [[ -e "${1}" ]]; then
        if ! [[ -e "${2}" ]]; then
            printf "%s -> %s\n:" "${1}" "${2}"
            ln -s "${1}" "${2}"
        fi
    fi

}

function cudaenv() {
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64
    export CUDA_HOME=/usr/local/cuda
    export PATH=$PATH:${CUDA_HOME}/bin
}

# Get SELinux/dnf/yum/rpm Python bindings symlink'd into the local python venv
# for Red Hat family of distros
rhtvenv() {
    local py_path
    py_path=$(which python)
    if ! [[ ${py_path} =~ 'virtualenv' ]] && [[ -z "${VIRTUAL_ENV}" ]]; then
        printf "NOT IN A VIRTUALENV!\n"
        return 1
    fi
    local venv_basepath="${py_path%*/*/*}"

    local py_version
    py_version=$(python -c 'import platform; print(platform.python_version());')
    local py_shortver="${py_version%*.*}"
    local pylib64_path="/usr/lib64/python${py_shortver}/site-packages/"
    local pylib_path="/usr/lib/python${py_shortver}/site-packages/"
    if ! [[ -d "${pylib64_path}" ]]; then
        printf "%s doesn't exist, check host python version!\n" "${pylib64_path}"
        return 1
    fi


    ## SELinux
    fn_conditionally_symlink "${pylib64_path}/selinux/" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/selinux"

    fn_conditionally_symlink "${pylib64_path}/semanage.py" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/semanage.py"

    local selinux_so
    selinux_so=$(find "${pylib64_path}" -name "_selinux*.so")
    fn_conditionally_symlink "${selinux_so}" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/${selinux_so##*/}"

    local semanage_so
    semanage_so=$(find "${pylib64_path}" -name "_semanage*.so")
    fn_conditionally_symlink "${semanage_so}" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/${semanage_so##*/}"

    ## RPM
    fn_conditionally_symlink "${pylib64_path}/rpm" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/rpm"

    ## DNF (YUM4)
    fn_conditionally_symlink "${pylib_path}/dnf" \
        "${venv_basepath}/lib/python${py_shortver}/site-packages/dnf"

    fn_conditionally_symlink "${pylib_path}/dnf-plugins" \
        "${venv_basepath}/lib/python${py_shortver}/site-packages/dnf-plugins"

    fn_conditionally_symlink "${pylib_path}/dnfpluginscore" \
        "${venv_basepath}/lib/python${py_shortver}/site-packages/dnfpluginscore"

    fn_conditionally_symlink "${pylib64_path}/libdnf" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/libdnf"

    fn_conditionally_symlink "${pylib64_path}/hawkey" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/hawkey"

    fn_conditionally_symlink "${pylib64_path}/libcomps" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/libcomps"

    fn_conditionally_symlink "${pylib64_path}/gpg" \
        "${venv_basepath}/lib64/python${py_shortver}/site-packages/gpg"

    ## YUM (<= 3.x)
    fn_conditionally_symlink "${pylib_path}/yum" \
        "${venv_basepath}/lib/python${py_shortver}/site-packages/yum"
    fn_conditionally_symlink "${pylib_path}/yumutils" \
                "${venv_basepath}/lib/python${py_shortver}/site-packages/yumutils"

    ## Insights Client
    fn_conditionally_symlink "${pylib_path}/insights_client" \
                "${venv_basepath}/lib/python${py_shortver}/site-packages/insights_client"

    ## firewalld 
    fn_conditionally_symlink "${pylib_path}/firewall" \
                "${venv_basepath}/lib/python${py_shortver}/site-packages/firewall"

    printf "DONE!\n"
}


# END: Misc functions
###############################################################################

###############################################################################
# BEGIN: Ansible hacking functions

# "Globals" for Ansible hacking functions
ansible_dev_dir="${HOME}/src/dev/ansible/"

ahack() {
    if [[ -d ${ansible_dev_dir} ]]; then
        pushd "${ansible_dev_dir}" || return
            make clean
            # shellcheck source=/dev/null
            source hacking/env-setup
        popd || return
    else
        printf "ERROR: Ansible dev dir not found: %s\n" "${ansible_dev_dir}"
    fi
}

aclean() {
    if [[ -d ${ansible_dev_dir} ]]; then
        pushd "|${ansible_dev_dir}" || return
            make clean
        popd || return
    else
        printf "ERROR: Ansible dev dir not found: %s\n" "${ansible_dev_dir}"
    fi
}

ardebug(){
    if [[ -d ~/.ansible/tmp ]]; then
        mapfile -t ardebug_dirs < <(ls "${HOME}/.ansible/tmp")
        pushd "${HOME}/.ansible/tmp/${ardebug_dirs[-1]}" || return
            python3 ./*.py explode && cd debug_dir || return
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
    git fetch upstream "pull/${1}/head:pr/${1}" && git checkout "pr/${1}"
}
grabmr () {
    git fetch upstream "merge-requests/${1}/head:mr/${1}" && git checkout "mr/${1}"
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
        if [[ "$(basename "${dir}")" != 'dev' ]]
        then
            pushd "${dir}" || return
                git gc
            popd &> /dev/null || return
        fi
    done

    for dir in ~/src/dev/*;
    do
        pushd "${dir}" || return
            git gc
        popd &> /dev/null || return
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

git_auto_bisect_ansible(){
    bad_branch=${1}
    good_branch=${2}
    reverse=${3}

    if [[ ${1} == "-h" ]] || [[ -z "${1}" ]]; then
        printf "git_auto_bisect_ansible bad_branch good_branch [reverse]\n"
    fi

    if [[ -z "${bad_branch}" ]] || [[ -z "${good_branch}" ]] ; then
        printf "Must provide both refs\n"
        return 1
    fi

    read -r -p "Test command: " test_command
    if [[ -z "${test_command}" ]]; then
        printf "Test command can not be empty\n"
        return 1
    fi

    if ! [[ -d "${HOME}/.virtualenvs/ansible/" ]]; then
        printf "No virtualenv named ansible.\n"
        return 1
    fi
    ahack # clean the env
    workon ansible

    git bisect start "${bad_branch}" "${good_branch}"

    if [[ -z "${reverse}" ]]; then
        eval "git bisect run ${test_command}"
    else
        eval "git bisect run bash -c '! ${test_command}'"
    fi
    git bisect reset

}

git_revlist_test_ansible(){
    branch=${1}

    if [[ ${1} == "-h" ]] || [[ -z "${1}" ]]; then
        printf "git_revlist_test \n"
    fi

    read -r -p "Test command: " test_command
    if [[ -z "${test_command}" ]]; then
        printf "Test command can not be empty\n"
        return 1
    fi

    if ! [[ -d "${HOME}/.virtualenvs/ansible/" ]]; then
        printf "No virtualenv named ansible.\n"
        return 1
    fi
    ahack # clean the env
    workon ansible

    for ref in $(git rev-list "${branch}")
    do
        printf "CHECKING OUT: %s\n" "${ref}"
        git checkout "${ref}"
        ahack
        if eval "${test_command}"; then 
            printf "First good commit found: %s \n" "${ref}"
            return 0
        fi
    done

}

# Various git aliases
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
alias sgh="show_git_head"
alias gaba="git_auto_bisect_ansible"
alias gph="git push"
alias gpo="git push origin"
alias gpl="git pull"
alias gpr="git pull --rebase"
alias gs="git status -sb"
alias gsh="git show --pretty='format:' --name-only"
alias gsl="git stash list"
alias gho="git hash-object"
alias gcf="git cat-file"
alias flog="vim +Flog"

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
        export "$PATHVARIABLE"="$NEWPATH"
}
pathprepend () {
        pathremove "$1" "$2"
        local PATHVARIABLE=${2:-PATH}
        export "$PATHVARIABLE"="$1${!PATHVARIABLE:+:${!PATHVARIABLE}}"
}

pathappend () {
        pathremove "$1" "$2"
        local PATHVARIABLE=${2:-PATH}
        export "$PATHVARIABLE"="${!PATHVARIABLE:+${!PATHVARIABLE}:}$1"
}

export GOPATH=$HOME/go
pathappend "${GOPATH}/bin"
pathappend "${HOME}/bin"
pathappend "${HOME}/.local/bin"
pathappend "${HOME}/.local/node_modules/.bin"
if [[ "penguin" == "${short_hostname}" ]]; then
    pathappend /usr/local/go/bin
fi

# END Modify PATH
###############################################################################


###############################################################################
# BEGIN: PROMPT and PS1 stuff

# local hostnames for my machines to set local PS1 colorscheme vs remote
_localhosts=("penguin" "x1carbongen9" "thinkcentrem75q5" "thinkpadt14s")
short_hostname=${HOSTNAME%%.*}
if [[ "penguin" == "${short_hostname}" ]]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
fi

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
        if [[ ${_localhosts[*]} =~ ${short_hostname} ]] && [[ -n "${short_hostname}" ]]; then
            # non-root prompt - local colorscheme
            local date_c=$red_c
            local user_c=$yellow_c
            local at_c=$blue_c
            if [[ -n "${TOOLBOX_PATH}" ]]; then
                local host_c=$teal_c
            else
                local host_c=$yellow_c
            fi
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
        if [[ ${_localhosts[*]} =~ ${short_hostname} ]] && [[ -n "${short_hostname}" ]]; then
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
        prompt_out+=" ~${PWD#"${HOME}"}"
    else
        prompt_out+=" $PWD"
    fi
    prompt_out+="$normal_c"
    prompt_out+="]"

    # shellcheck disable=SC2059
    printf "$prompt_out\n"

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
