#!/bin/bash

# termux shebang line /data/data/com.termux/files/usr/bin/bash

src_dir="${HOME}/src"
dev_dir="${src_dir}/dev"
collections_dir="${dev_dir}/ansible_collections"

# Small script to setup git repos I work in frequently

for dir in "${dev_dir}" "${collections_dir}";
do
    if ! [ -d "${dir}" ]; then
        mkdir -p "${dir}"
    fi
done

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
    "${dev_dir}/ansible" \
    git@github.com:maxamillion/ansible.git \
    https://github.com/ansible/ansible.git

f_git_clone_with_upstream \
    "${dev_dir}/molecule" \
    git@github.com:maxamillion/molecule.git \
    https://github.com/ansible/molecule.git

f_git_clone_with_upstream \
    "${dev_dir}/workshops" \
    git@github.com:maxamillion/workshops.git \
    https://github.com/ansible/workshops.git

f_git_clone_with_upstream \
    "${dev_dir}/zuul-jobs" \
    git@github.com:maxamillion/ansible-zuul-jobs.git \
    https://github.com/ansible/ansible-zuul-jobs.git

f_git_clone_with_upstream \
    "${dev_dir}/zuul-project-config" \
    git@github.com:maxamillion/project-config.git \
    https://github.com/ansible/project-config.git

f_git_clone_with_upstream \
    "${dev_dir}/ansible-runner" \
    git@github.com:maxamillion/ansible-runner.git \
    https://github.com/ansible/ansible-runner.git

f_git_clone_with_upstream \
    "${dev_dir}/ids_install" \
    git@github.com:maxamillion/ids_install.git \
    https://github.com/ansible-security/ids_install.git

f_git_clone_with_upstream \
    "${dev_dir}/ids_config" \
    git@github.com:maxamillion/ids_config.git \
    https://github.com/ansible-security/ids_config.git

f_git_clone_with_upstream \
    "${dev_dir}/ids_rule" \
    git@github.com:maxamillion/ids_rule.git \
    https://github.com/ansible-security/ids_rule.git

f_git_clone_with_upstream \
    "${dev_dir}/openshift-ansible" \
    git@github.com:maxamillion/openshift-ansible.git \
    https://github.com/openshift/openshift-ansible.git

f_git_clone_with_upstream \
    "${dev_dir}/dnf" \
    git@github.com:maxamillion/dnf.git \
    https://github.com/rpm-software-management/dnf.git

f_git_clone_with_upstream \
    "${dev_dir}/releng" \
    ssh://git@pagure.io/forks/maxamillion/releng.git \
    https://pagure.io/releng.git

f_git_clone_with_upstream \
    "${dev_dir}/releng-automation" \
    ssh://git@pagure.io/forks/maxamillion/releng-automation.git \
    https://pagure.io/releng-automation.git

f_git_clone_with_upstream \
    "${dev_dir}/fedora-kickstarts" \
    ssh://git@pagure.io/forks/maxamillion/fedora-kickstarts.git \
    https://pagure.io/fedora-kickstarts.git

# my code, not forked from elsewhere
f_git_clone \
    "${src_dir}/maxible" \
    git@github.com:maxamillion/maxible.git

# upstream code
f_git_clone \
    "${src_dir}/yum" \
    https://github.com/rpm-software-management/yum.git

f_git_clone \
    "${src_dir}/yum-utils" \
    https://github.com/rpm-software-management/yum-utils.git

# my ansible collections
f_git_clone \
    "${collections_dir}/maxamillion/devel" \
    git@github.com:maxamillion/ansible_collections.maxamillion.devel.git

# forked collections I contribute to
f_git_clone_with_upstream \
    "${collections_dir}/ibm/qradar" \
    git@github.com:maxamillion/ibm_qradar.git \
    https://github.com/ansible-security/ibm_qradar.git

f_git_clone_with_upstream \
    "${collections_dir}/ibm/isam" \
    git@github.com:maxamillion/isam-ansible-roles.git \
    https://github.com/IBM-Security/isam-ansible-roles.git

f_git_clone_with_upstream \
    "${collections_dir}/splunk/enterprise_security" \
    git@github.com:maxamillion/splunk_enterprise_security.git \
    https://github.com/ansible-security/splunk_enterprise_security.git

f_git_clone_with_upstream \
    "${collections_dir}/symantec/epm" \
    git@github.com:maxamillion/ansible_collections.symantec.epm.git \
    https://github.com/ansible-security/ansible_collections.symantec.epm.git

f_git_clone_with_upstream \
    "${collections_dir}/trendmicro/deepsecurity" \
    git@github.com:maxamillion/ansible_collections.trendmicro.deepsecurity.git \
    https://github.com/ansible-security/ansible_collections.deepsecurity.deepsecurity.git

