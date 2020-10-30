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

fn_git_clone() {
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

fn_git_clone_with_upstream() {
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

# local_clone_destination_dir my_fork_or_repo [upstream_repo]
git_repos=(
    "${dev_dir}/ansible git@github.com:maxamillion/ansible.git https://github.com/ansible/ansible.git"
    "${dev_dir}/ansible-examples git@github.com:maxamillion/ansible-examples.git https://github.com/ansible/ansible-examples.git"
    "${dev_dir}/ansible-runner git@github.com:maxamillion/ansible-runner.git https://github.com/ansible/ansible-runner.git"
    "${dev_dir}/ansible-builder git@github.com:maxamillion/ansible-builder.git https://github.com/ansible/ansible-builder.git"
    "${dev_dir}/awx git@github.com:maxamillion/awx.git https://github.com/ansible/awx.git"
    "${dev_dir}/awx-resource-operator git@github.com:maxamillion/awx-resource-operator.git https://github.com/ansible/awx-resource-operator.git"
    "${dev_dir}/ansible-bender git@github.com:maxamillion/ansible-bender.git https://github.com/ansible-community/ansible-bender.git"
    "${dev_dir}/receptor git@github.com:maxamillion/receptor.git https://github.com/project-receptor/receptor.git"
    "${dev_dir}/molecule git@github.com:maxamillion/molecule.git https://github.com/ansible/molecule.git"
    "${dev_dir}/workshops git@github.com:maxamillion/workshops.git https://github.com/ansible/workshops.git"
    "${dev_dir}/workshop-examples git@github.com:maxamillion/workshop-examples.git https://github.com/ansible-security/workshop-examples.git"
    "${dev_dir}/zuul-jobs git@github.com:maxamillion/ansible-zuul-jobs.git https://github.com/ansible/ansible-zuul-jobs.git"
    "${dev_dir}/zuul-project-config git@github.com:maxamillion/project-config.git https://github.com/ansible/project-config.git"
    "${dev_dir}/zuul-windmill-config git@github.com:maxamillion/windmill-config.git https://github.com/maxamillion/windmill-config.git"
    "${dev_dir}/ids_install git@github.com:maxamillion/ids_install.git https://github.com/ansible-security/ids_install.git"
    "${dev_dir}/ids_config git@github.com:maxamillion/ids_config.git https://github.com/ansible-security/ids_config.git"
    "${dev_dir}/ids_rule git@github.com:maxamillion/ids_rule.git https://github.com/ansible-security/ids_rule.git"
    "${dev_dir}/openshift-ansible git@github.com:maxamillion/openshift-ansible.git https://github.com/openshift/openshift-ansible.git"
    "${dev_dir}/dnf git@github.com:maxamillion/dnf.git https://github.com/rpm-software-management/dnf.git"
    "${dev_dir}/toolbox git@github.com:maxamillion/toolbox.git https://github.com/containers/toolbox.git"
    "${dev_dir}/releng ssh://git@pagure.io/forks/maxamillion/releng.git https://pagure.io/releng.git"
    "${dev_dir}/releng-automation ssh://git@pagure.io/forks/maxamillion/releng-automation.git https://pagure.io/releng-automation.git"
    "${dev_dir}/fedora-kickstarts ssh://git@pagure.io/forks/maxamillion/fedora-kickstarts.git https://pagure.io/fedora-kickstarts.git"
    "${dev_dir}/baremetal-deploy git@github.com:maxamillion/baremetal-deploy.git https://github.com/openshift-kni/baremetal-deploy.git"
    "${dev_dir}/kubespray git@github.com:maxamillion/kubespray.git https://github.com/kubernetes-sigs/kubespray"
    "${src_dir}/maxible git@github.com:maxamillion/maxible.git"
    "${src_dir}/yum https://github.com/rpm-software-management/yum.git"
    "${src_dir}/yum-utils https://github.com/rpm-software-management/yum-utils.git"
#    "${src_dir}/fedora-infra-ansible https://infrastructure.fedoraproject.org/infra/ansible.git"
    "${src_dir}/firewalld https://github.com/firewalld/firewalld.git"
    "${collections_dir}/maxamillion/devel git@github.com:maxamillion/ansible_collections.maxamillion.devel.git"
    "${collections_dir}/ibm/qradar git@github.com:maxamillion/ibm_qradar.git https://github.com/ansible-collections/ibm.qradar.git"
    "${collections_dir}/ibm/isam git@github.com:maxamillion/isam-ansible-roles.git https://github.com/IBM-Security/isam-ansible-roles.git"
    "${collections_dir}/splunk/es git@github.com:maxamillion/splunk.es.git https://github.com/ansible-collections/splunk.es.git"
    "${collections_dir}/symantec/epm git@github.com:maxamillion/ansible_collections.symantec.epm.git https://github.com/ansible-collections/symantec.epm.git"
    "${collections_dir}/trendmicro/deepsecurity git@github.com:maxamillion/ansible_collections.trendmicro.deepsecurity.git https://github.com/ansible-security/ansible_collections.deepsecurity.deepsecurity.git"
    "${collections_dir}/crowdstrike/falcon git@github.com:maxamillion/ansible_collections.crowdstrike.falcon.git https://github.com/ansible-security/ansible_collections.crowdstrike.falcon.git"
    "${collections_dir}/ansible/posix git@github.com:maxamillion/ansible.posix.git https://github.com/ansible-collections/ansible.posix.git"
    "${collections_dir}/ansible/netcommon git@github.com:maxamillion/netcommon.git https://github.com/ansible-collections/netcommon.git"
    "${collections_dir}/community/general git@github.com:maxamillion/community.general.git https://github.com/ansible-collections/community.general.git"
    "${collections_dir}/community/kubernetes git@github.com:maxamillion/community.kubernetes.git https://github.com/ansible-collections/community.kubernetes.git"
    "${collections_dir}/community/okd git@github.com:maxamillion/community.okd.git https://github.com/ansible-collections/community.okd.git"
    "${collections_dir}/community/qradar git@github.com:maxamillion/community.qradar.git https://github.com/ansible-collections/community.qradar.git"
    "${collections_dir}/community/es git@github.com:maxamillion/community.es.git https://github.com/ansible-collections/community.es.git"
    "${collections_dir}/containers/podman git@github.com:maxamillion/ansible-podman-collections.git https://github.com/containers/ansible-podman-collections.git"
#    "${collections_dir}/community/epm git@github.com:maxamillion/community.epm.git https://github.com/ansible-collections/community.epm.git"
)

for repo_string in "${git_repos[@]}"
do
    readarray -d ' ' repo_string_split <<< "${repo_string}"
    if [ "${#repo_string_split[@]}" -eq 2 ]; then
        fn_git_clone "${repo_string_split[0]}" "${repo_string_split[1]}"
    elif [ "${#repo_string_split[@]}" -eq 3 ]; then
        fn_git_clone_with_upstream "${repo_string_split[0]}" "${repo_string_split[1]}" "${repo_string_split[2]}"
    fi
done

