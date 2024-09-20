#!/bin/bash

source ./bootstrap-lib.sh

src_dir="${HOME}/src"
dev_dir="${src_dir}/dev"
collections_dir="${dev_dir}/ansible_collections"
execenvs_dir="${dev_dir}/ansible_execenvs"

# Small script to setup git repos I work in frequently

for dir in "${dev_dir}" "${collections_dir}";
do
    fn_mkdir_if_needed "${dir}"
done

fn_git_clone() {
    # $1 - Target clone dir
    # $2 - git repo
    fn_mkdir_if_needed $(dirname $1)
    if ! [ -d $1 ]; then
        pushd $(dirname $1)
        git clone $2 $(basename $1)
        popd || exit
    fi
}

fn_git_clone_with_upstream() {
    # $1 - Target clone dir
    # $2 - My git fork url
    # $3 - Upstream git url
    fn_mkdir_if_needed $(dirname $1)
    if ! [ -d $1 ]; then
        pushd $(dirname $1)
        if git clone $2 $(basename $1); then
            pushd $(basename $1)
                git remote add upstream $3
            popd || exit
        popd || exit
        fi
    fi
}

# local_clone_destination_dir my_fork_or_repo [upstream_repo]
git_repos=(
    "${dev_dir}/pytorch git@github.com:maxamillion/pytorch.git https://github.com/pytorch/pytorch.git"
    "${dev_dir}/notebooks git@github.com:maxamillion/notebooks.git https://github.com/opendatahub-io/notebooks.git"
    "${dev_dir}/archey4 git@github.com:maxamillion/archey4.git https://github.com/HorlogeSkynet/archey4.git"
    "${dev_dir}/rebuilding-the-wheel git@gitlab.com:maxamillion/rebuilding-the-wheel.git https://gitlab.com/fedora/sigs/ai-ml/rebuilding-the-wheel.git"
    "${dev_dir}/requirements-pipeline git@gitlab.com:maxamillion/requirements-pipeline.git git@gitlab.com:redhat/rhel-ai/wheels/requirements-pipeline.git"
    "${dev_dir}/builder git@gitlab.com:maxamillion/builder.git git@gitlab.com:redhat/rhel-ai/wheels/builder.git"
    "${dev_dir}/fromager git@gitlab.com:maxamillion/fromager.git https://github.com/python-wheel-build/fromager.git"
    "${dev_dir}/ansible git@github.com:maxamillion/ansible.git https://github.com/ansible/ansible.git"
    "${dev_dir}/ara git@github.com:maxamillion/ara.git https://github.com/ansible-community/ara.git"
    "${dev_dir}/ansible-examples git@github.com:maxamillion/ansible-examples.git https://github.com/ansible/ansible-examples.git"
    "${dev_dir}/handbook git@github.com:maxamillion/handbook.git git@github.com:ansible/handbook.git"
    "${dev_dir}/ansible-runner git@github.com:maxamillion/ansible-runner.git https://github.com/ansible/ansible-runner.git"
    "${dev_dir}/ansible-rulebook git@github.com:maxamillion/ansible-rulebook.git https://github.com/ansible/ansible-rulebook.git"
    "${dev_dir}/ansible-sdk git@github.com:maxamillion/ansible-sdk.git https://github.com/ansible/ansible-sdk.git"
    "${dev_dir}/ansible-dev-tools git@github.com:maxamillion/ansible-cdk.git https://github.com/ansible-community/ansible-dev-tools.git"
    "${dev_dir}/ansible-lint git@github.com:maxamillion/ansible-lint.git https://github.com/ansible/ansible-lint.git"
    "${dev_dir}/ansible-builder git@github.com:maxamillion/ansible-builder.git https://github.com/ansible/ansible-builder.git"
    "${dev_dir}/ansible-creator git@github.com:maxamillion/ansible-creator.git https://github.com/ansible/ansible-creator.git"
    "${dev_dir}/ansible-community git@github.com:maxamillion/community.git https://github.com/ansible/community.git"
    "${dev_dir}/community-website git@github.com:maxamillion/community-website.git https://github.com/ansible-community/community-website.git"
    "${dev_dir}/dnf git@github.com:maxamillion/dnf.git https://github.com/rpm-software-management/dnf.git"
    "${dev_dir}/mock git@github.com:maxamillion/mock.git https://github.com/rpm-software-management/mock.git"
    "${dev_dir}/toolbox git@github.com:maxamillion/toolbox.git https://github.com/containers/toolbox.git"
    "${dev_dir}/releng ssh://git@pagure.io/forks/maxamillion/releng.git https://pagure.io/releng.git"
    "${dev_dir}/releng-automation ssh://git@pagure.io/forks/maxamillion/releng-automation.git https://pagure.io/releng-automation.git"
    "${dev_dir}/fedora-kickstarts ssh://git@pagure.io/forks/maxamillion/fedora-kickstarts.git https://pagure.io/fedora-kickstarts.git"
    "${dev_dir}/baremetal-deploy git@github.com:maxamillion/baremetal-deploy.git https://github.com/openshift-kni/baremetal-deploy.git"
    "${dev_dir}/kubespray git@github.com:maxamillion/kubespray.git https://github.com/kubernetes-sigs/kubespray.git"
    "${dev_dir}/kind git@github.com:maxamillion/kind.git https://github.com/kubernetes-sigs/kind"
    "${dev_dir}/greenboot git@github.com:maxamillion/greenboot.git https://github.com/fedora-iot/greenboot.git"
    "${dev_dir}/minikube git@github.com:maxamillion/minikube.git https://github.com/kubernetes/minikube.git"
    "${dev_dir}/operator-sdk git@github.com:maxamillion/operator-sdk.git https://github.com/operator-framework/operator-sdk"
    "${dev_dir}/podman git@github.com:maxamillion/podman.git https://github.com/containers/podman"
    "${dev_dir}/podman-system-role git@github.com:maxamillion/podman-system-role.git https://github.com/linux-system-roles/podman.git"
    "${dev_dir}/distrobox git@github.com:maxamillion/distrobox.git https://github.com/89luca89/distrobox.git"
    "${dev_dir}/layering-examples git@github.com:maxamillion/layering-examples.git https://github.com/coreos/layering-examples.git"
    "${dev_dir}/instructlab git@github.com:maxamillion/instructlab.git https://github.com/instructlab/instructlab.git"
    "${dev_dir}/taxonomy git@github.com:maxamillion/taxonomy.git https://github.com/instructlab/taxonomy.git"
    "${dev_dir}/ai-lab-recipes git@github.com:maxamillion/ai-lab-recipes.git https://github.com/containers/ai-lab-recipes.git"
    "${dev_dir}/dool git@github.com:maxamillion/dool.git https://github.com/scottchiefbaker/dool.git"
    "${src_dir}/maxible git@github.com:maxamillion/maxible.git"
    "${src_dir}/maxamillion.github.io git@github.com:maxamillion/maxamillion.github.io.git"
    "${src_dir}/yum https://github.com/rpm-software-management/yum.git"
    "${src_dir}/yum-utils https://github.com/rpm-software-management/yum-utils.git"
    "${src_dir}/firewalld https://github.com/firewalld/firewalld.git"
    "${src_dir}/portfolio-architecture-examples https://gitlab.com/redhatdemocentral/portfolio-architecture-examples.git"
    "${src_dir}/fedora-infra-ansible https://infrastructure.fedoraproject.org/infra/ansible.git"
    # "${dev_dir}/ansible-zuul-jobs git@github.com:maxamillion/ansible-zuul-jobs.git https://github.com/ansible/ansible-zuul-jobs.git"
    # "${dev_dir}/ansible-operator-plugins git@github.com:maxamillion/ansible-operator-plugins.git https://github.com/operator-framework/ansible-operator-plugins.git"
    # "${dev_dir}/ansible.pages.redhat.com git@gitlab.cee.redhat.com:admiller/ansible.pages.redhat.com.git https://gitlab.cee.redhat.com/ansible/ansible.pages.redhat.com.git"
    # "${dev_dir}/ansible-hub-ui git@github.com:maxamillion/ansible-hub-ui.git https://github.com/ansible/ansible-hub-ui.git"
    # "${dev_dir}/ansible-bender git@github.com:maxamillion/ansible-bender.git https://github.com/ansible-community/ansible-bender.git"
    # "${dev_dir}/ansible-risk-insight git@github.com:maxamillion/ansible-risk-insight.git https://github.com/ansible/ansible-risk-insight.git"
    # "${dev_dir}/ansible-scan-core git@github.com:maxamillion/ansible-scan-core.git git@github.com:ansible/ansible-scan-core.git"
    # "${dev_dir}/ansible-gatekeeper git@github.com:maxamillion/ansible-gatekeeper.git git@github.com:ansible/ansible-gatekeeper.git"
    # "${dev_dir}/ansible-demo-policies git@github.com:maxamillion/ansible-demo-policies.git git@github.com:ansible/ansible-demo-policies.git"
    # "${dev_dir}/ansible-language-server git@github.com:maxamillion/ansible-language-server.git https://github.com/ansible/ansible-language-server.git"
    # "${dev_dir}/openshift-ansible git@github.com:maxamillion/openshift-ansible.git https://github.com/openshift/openshift-ansible.git"
    # "${dev_dir}/ecosystem-documentation git@github.com:maxamillion/ecosystem-documentation.git https://github.com/ansible/ecosystem-documentation.git"
    # "${dev_dir}/awx git@github.com:maxamillion/awx.git https://github.com/ansible/awx.git"
    # "${dev_dir}/awx-resource-operator git@github.com:maxamillion/awx-resource-operator.git https://github.com/ansible/awx-resource-operator.git"
    # "${dev_dir}/aap-upstream-ci git@github.com:maxamillion/aap-upstream-ci.git git@github.com:ansible/aap-upstream-ci.git"
    # "${dev_dir}/galaxy_ng git@github.com:maxamillion/galaxy_ng.git https://github.com/ansible/galaxy_ng.git"
    # "${dev_dir}/automation-platform-collection git@github.com:maxamillion/automation-platform-collection.git git@github.com:ansible/automation-platform-collection.git"
    # "${dev_dir}/automation-platform-setup git@github.com:maxamillion/automation-platform-setup.git git@github.com:ansible/automation-platform-setup.git"
    # "${dev_dir}/el_grandiose_module_promoter git@github.com:maxamillion/el_grandiose_module_promoter.git https://github.com/ansible-collections/el_grandiose_module_promoter.git"
    # "${dev_dir}/receptor git@github.com:maxamillion/receptor.git https://github.com/ansible/receptor.git"
    # "${dev_dir}/molecule git@github.com:maxamillion/molecule.git https://github.com/ansible/molecule.git"
    # "${dev_dir}/workshops git@github.com:maxamillion/workshops.git https://github.com/ansible/workshops.git"
    # "${dev_dir}/device-edge-workshops git@github.com:maxamillion/device-edge-workshops.git https://github.com/redhat-manufacturing/device-edge-workshops.git"
    # "${dev_dir}/workshop-examples git@github.com:maxamillion/workshop-examples.git https://github.com/ansible-security/workshop-examples.git"
    # "${dev_dir}/zuul-jobs git@github.com:maxamillion/ansible-zuul-jobs.git https://github.com/ansible/ansible-zuul-jobs.git"
    # "${dev_dir}/zuul-config git@github.com:maxamillion/zuul-config.git https://github.com/ansible/ansible-config.git"
    # "${dev_dir}/zuul-project-config git@github.com:maxamillion/project-config.git https://github.com/ansible/project-config.git"
    # "${dev_dir}/zuul-windmill-config git@github.com:maxamillion/windmill-config.git https://github.com/maxamillion/windmill-config.git"
    # "${dev_dir}/osbuild-composer git@github.com:maxamillion/osbuild-composer.git https://github.com/osbuild/osbuild-composer.git"
    # "${dev_dir}/osbuild git@github.com:maxamillion/osbuild.git https://github.com/osbuild/osbuild.git"
    # "${dev_dir}/cloud-connector git@github.com:maxamillion/cloud-connector.git https://github.com/RedHatInsights/cloud-connector.git"
    # "${dev_dir}/yggdrasil git@github.com:maxamillion/yggdrasil.git https://github.com/RedHatInsights/yggdrasil.git"
    # "${dev_dir}/playbook-dispatcher git@github.com:maxamillion/playbook-dispatcher.git https://github.com/RedHatInsights/playbook-dispatcher.git"
    # "${dev_dir}/rhc-worker-playbook git@github.com:maxamillion/rhc-worker-playbook.git https://github.com/RedHatInsights/rhc-worker-playbook.git"
    # "${dev_dir}/insights-core git@github.com:maxamillion/insights-core.git https://github.com/RedHatInsights/insights-core.git"
    # "${dev_dir}/awx-operator git@github.com:maxamillion/awx-operator.git https://github.com/ansible/awx-operator.git"
    # "${dev_dir}/ids_install git@github.com:maxamillion/ids_install.git https://github.com/ansible-security/ids_install.git"
    # "${dev_dir}/ids_config git@github.com:maxamillion/ids_config.git https://github.com/ansible-security/ids_config.git"
    # "${dev_dir}/ids_rule git@github.com:maxamillion/ids_rule.git https://github.com/ansible-security/ids_rule.git"
    # "${src_dir}/k4e-operator https://github.com/jakub-dzon/k4e-operator.git"
    # "${src_dir}/k4e-device-worker https://github.com/jakub-dzon/k4e-device-worker.git"
    # "${src_dir}/meta-rpm https://gitlab.com/fedora-iot/meta-rpm.git"
    # "${collections_dir}/maxamillion/devel git@github.com:maxamillion/ansible_collections.maxamillion.devel.git"
    # "${collections_dir}/consoledot/edgemanagement git@github.com:maxamillion/consoledot.edgemanagement.git https://github.com/ansible-collections/consoledot.edgemanagement.git"
    # "${collections_dir}/ansible/eda git@github.com:maxamillion/ansible.eda.git https://github.com/ansible/event-driven-ansible"
    # "${collections_dir}/ansible/posix git@github.com:maxamillion/ansible.posix.git https://github.com/ansible-collections/ansible.posix.git"
    # "${collections_dir}/ansible/utils git@github.com:maxamillion/ansible.utils.git https://github.com/ansible-collections/ansible.utils.git"
    # "${collections_dir}/ansible/netcommon git@github.com:maxamillion/ansible.netcommon.git https://github.com/ansible-collections/ansible.netcommon.git"
    # "${collections_dir}/ansible/content_builder git@github.com:maxamillion/ansible.content_builder.git https://github.com/ansible-community/ansible.content_builder.git"
    # "${collections_dir}/ansible/containerized_installer git@gitlab.cee.redhat.com:admiller/aap-containerized-installer.git git@gitlab.cee.redhat.com:ansible/aap-containerized-installer.git"
    # "${collections_dir}/community/general git@github.com:maxamillion/community.general.git https://github.com/ansible-collections/community.general.git"
    # "${collections_dir}/community/kubernetes git@github.com:maxamillion/community.kubernetes.git https://github.com/ansible-collections/community.kubernetes.git"
    # "${collections_dir}/community/okd git@github.com:maxamillion/community.okd.git https://github.com/ansible-collections/community.okd.git"
    # "${collections_dir}/community/cip git@github.com:maxamillion/community.cip.git https://github.com/ansible-collections/community.cip.git"
    # "${collections_dir}/community/vmware git@github.com:maxamillion/community.vmware.git https://github.com/ansible-collections/community.vmware.git"
    # "${collections_dir}/cloud/common git@github.com:maxamillion/cloud.common.git https://github.com/ansible-collections/cloud.common.git"
    # "${collections_dir}/containers/podman git@github.com:maxamillion/ansible-podman-collections.git https://github.com/containers/ansible-podman-collections.git"
    # "${collections_dir}/infra/osbuild git@github.com:maxamillion/infra.osbuild.git https://github.com/redhat-cop/infra.osbuild.git"
    # "${collections_dir}/fedora/iot git@github.com:maxamillion/fedora.iot.git"
    # "${collections_dir}/osbuild/composer git@github.com:maxamillion/osbuild.composer.git https://github.com/ansible-collections/osbuild.composer.git"
    # "${collections_dir}/edge/workload git@github.com:maxamillion/edge.workload.git https://github.com/ansible-collections/edge.workload.git"
    # "${collections_dir}/edge/microshift git@github.com:maxamillion/edge.microshift.git https://github.com/ansible-collections/edge.microshift.git"
    # "${collections_dir}/edge/test_utils git@github.com:maxamillion/edge.test_utils.git https://github.com/ansible-collections/edge.test_utils.git"
    # "${collections_dir}/redhat_cop/controller_configuration git@github.com:maxamillion/controller_configuration.git https://github.com/redhat-cop/controller_configuration.git"
    # "${collections_dir}/redhat_cop/ah_configuration git@github.com:maxamillion/ah_configuration.git https://github.com/redhat-cop/ah_configuration.git"
    # "${collections_dir}/redhat_cop/ee_utilities git@github.com:maxamillion/ee_utilities.git https://github.com/redhat-cop/ee_utilities.git"
    # "${collections_dir}/redhat_cop/aap_utilities git@github.com:maxamillion/aap_utilities.git https://github.com/redhat-cop/aap_utilities.git"
    # "${collections_dir}/kubevirt/core git@github.com:maxamillion/kubevirt.core.git https://github.com/kubevirt/kubevirt.core"
    # "${collections_dir}/kubernetes/core git@github.com:maxamillion/kubernetes.core.git https://github.com/ansible-collections/kubernetes.core"
    # "${collections_dir}/vmware/vmware_rest git@github.com:maxamillion/vmware.vmware_rest.git https://github.com/ansible-collections/vmware.vmware_rest.git"
    # "${collections_dir}/community/qradar git@github.com:maxamillion/community.qradar.git https://github.com/ansible-collections/community.qradar.git"
    # "${collections_dir}/community/es git@github.com:maxamillion/community.es.git https://github.com/ansible-collections/community.es.git"
    # "${collections_dir}/ibm/qradar git@github.com:maxamillion/ibm_qradar.git https://github.com/ansible-collections/ibm.qradar.git"
    # "${collections_dir}/ibm/isam git@github.com:maxamillion/isam-ansible-roles.git https://github.com/IBM-Security/isam-ansible-roles.git"
    # "${execenvs_dir}/fedora.iot git@github.com:maxamillion/execenv.fedora.iot.git"
)

for repo_string in "${git_repos[@]}"
do
    readarray -d ' ' repo_string_split <<< "${repo_string}"
    if [ "${#repo_string_split[@]}" -eq 2 ]; then
        fn_git_clone "${repo_string_split[0]}" "${repo_string_split[1]}"
    elif [ "${#repo_string_split[@]}" -eq 3 ]; then
        fn_git_clone_with_upstream "${repo_string_split[0]}" "${repo_string_split[1]}" "${repo_string_split[2]}"
    fi
    if [[ "${repo_string_split[0]}" =~ "${collections_dir}" ]]; then
        collection_shortdir="${repo_string_split[0]#${collections_dir}/*}"
        fn_mkdir_if_needed ${HOME}/.ansible/collections/ansible_collections/${collection_shortdir%*/*}
        fn_symlink_if_needed ${repo_string_split[0]} ${HOME}/.ansible/collections/ansible_collections/${collection_shortdir}
    fi
done
