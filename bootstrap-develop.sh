#!/bin/bash

# termux shebang line /data/data/com.termux/files/usr/bin/bash

# Small script to setup git repos I work in frequently

if ! [ -d ~/src/dev ]; then
    mkdir -p ~/src/dev
fi

if ! [ -d ~/src/dev/ansible_collections ]; then
    mkdir -p ~/src/dev/ansible_collections
fi

f_git_clone() {
    # $1 - Target clone dir
    # $2 - git repo
    if ! [ -d $(dirname $1) ]; then
        mkdir -p $(dirname $1)
    fi
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
    if ! [ -d $(dirname $1) ]; then
        mkdir -p $(dirname $1)
    fi
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
    ~/src/dev/molecule \
    git@github.com:maxamillion/molecule.git \
    https://github.com/ansible/molecule.git

f_git_clone_with_upstream \
    ~/src/dev/workshops \
    git@github.com:maxamillion/workshops.git \
    https://github.com/ansible/workshops.git

f_git_clone_with_upstream \
    ~/src/dev/zuul-jobs \
    git@github.com:maxamillion/ansible-zuul-jobs.git \
    https://github.com/ansible/ansible-zuul-jobs.git

f_git_clone_with_upstream \
    ~/src/dev/zuul-project-config \
    git@github.com:maxamillion/project-config.git \
    https://github.com/ansible/project-config.git

f_git_clone_with_upstream \
    ~/src/dev/ansible-runner \
    git@github.com:maxamillion/ansible-runner.git \
    https://github.com/ansible/ansible-runner.git

f_git_clone_with_upstream \
    ~/src/dev/ids_install \
    git@github.com:maxamillion/ids_install.git \
    https://github.com/ansible-security/ids_install.git

f_git_clone_with_upstream \
    ~/src/dev/ids_config \
    git@github.com:maxamillion/ids_config.git \
    https://github.com/ansible-security/ids_config.git

f_git_clone_with_upstream \
    ~/src/dev/ids_rule \
    git@github.com:maxamillion/ids_rule.git \
    https://github.com/ansible-security/ids_rule.git

f_git_clone_with_upstream \
    ~/src/dev/ansible_collections/ibm/qradar \
    git@github.com:maxamillion/ibm_qradar.git \
    https://github.com/ansible-security/ibm_qradar.git

f_git_clone_with_upstream \
    ~/src/dev/ansible_collections/splunk/enterprise_security\
    git@github.com:maxamillion/splunk_enterprise_security.git \
    https://github.com/ansible-security/splunk_enterprise_security.git

f_git_clone_with_upstream \
    ~/src/dev/openshift-ansible \
    git@github.com:maxamillion/openshift-ansible.git \
    https://github.com/openshift/openshift-ansible.git

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

f_git_clone_with_upstream \
    ~/src/dev/fedora-kickstarts \
    ssh://git@pagure.io/forks/maxamillion/fedora-kickstarts.git \
    https://pagure.io/fedora-kickstarts.git

f_git_clone \
    ~/src/maxible \
    git@github.com:maxamillion/maxible.git

f_git_clone \
    ~/src/dev/ansible_collections/maxamillion/devel \
    git@github.com:maxamillion/ansible_collections.maxamillion.devel.git

# upstream code
f_git_clone \
    ~/src/yum \
    https://github.com/rpm-software-management/yum.git

f_git_clone \
    ~/src/yum-utils \
    https://github.com/rpm-software-management/yum-utils.git

