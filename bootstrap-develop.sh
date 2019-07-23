#!/bin/bash

# termux shebang line /data/data/com.termux/files/usr/bin/bash

# Small script to setup git repos I work in frequently

mkdir -p ~/src/dev
mkdir ~/ansible

f_git_clone() {
    # $1 - Target clone dir
    # $2 - git repo
    if ! [ -d $1 ]; then
        pushd $(dirname $1)
        git clone $2 $(basename $1)
        popd
    fi
}

f_git_clone_with_upstream() {
    # $1 - Target clone dir
    # $2 - My git fork url
    # $3 - Upstream git url
    if ! [ -d $1 ]; then
        pushd $(dirname $1)
        git clone $2 $(basename $1)
            pushd $(basename $1)
                git remote add upstream $3
            popd
        popd
    fi
}

# Upstream Forks
f_git_clone_with_upstream \
    ~/src/dev/ansible \
    git@github.com:maxamillion/ansible.git \
    https://github.com/ansible/ansible.git

f_git_clone_with_upstream \
    ~/src/dev/ansible-runner \
    git@github.com:maxamillion/ansible-runner.git \
    https://github.com/ansible/ansible-runner.git

f_git_clone_with_upstream \
    ~/src/dev/openshift-ansible \
    git@github.com:maxamillion/openshift-ansible.git \
    https://github.com/openshift/openshift-ansible.git

f_git_clone_with_upstream \
    ~/src/dev/dnf \
    git@github.com:maxamillion/dnf.git \
    https://github.com/rpm-software-management/dnf.git

f_git_clone_with_upstream \
    ~/src/dev/dnf \
    git@github.com:maxamillion/dnf.git \
    https://github.com/rpm-software-management/dnf.git

f_git_clone_with_upstream \
    ~/src/dev/releng \
    ssh://git@pagure.io/forks/maxamillion/releng.git \
    https://pagure.io/releng.git

f_git_clone_with_upstream \
    ~/src/dev/releng-automation \
    ssh://git@pagure.io/forks/maxamillion/releng-automation.git \
    https://pagure.io/releng-automation.git

f_git_clone \
    ~/ansible/maxible \
    git@github.com:maxamillion/maxible.git


# upstream code
f_git_clone \
    ~/src/yum \
    https://github.com/rpm-software-management/yum.git

f_git_clone \
    ~/src/yum-utils \
    https://github.com/rpm-software-management/yum-utils.git
