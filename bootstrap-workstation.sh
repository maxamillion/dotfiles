#!/bin/bash
source ./bootstrap-lib.sh
fn_check_distro

if [[ "${ID}" == "debian" ]]; then
    # local user ssh agent
    fn_local_user_ssh_agent

    fn_system_setup_crostini
    # rustup
    fn_local_install_rustup

    fn_local_install_neovim
fi

if [[ "${ID}" == "Termux" ]]; then
    # local user ssh agent
    fn_local_user_ssh_agent

    fn_system_setup_crostini
fi

if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || ${ID} == "fedora" ]]; then
    fn_system_setup_fedora_el

    # virtualenvwrapper
    # fn_local_install_virtualenvwrapper

    if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
        fn_local_install_neovim
    fi

fi

# k8s stuff
fn_local_install_minikube
fn_local_install_kind
fn_local_install_helm
fn_local_install_kustomize
fn_local_install_kubectl
fn_local_install_k9s
fn_local_install_kubebuilder
fn_local_install_operator_sdk

# rosa
fn_local_install_rosa

# terraform
fn_local_install_terraform

# uv tool install
fn_local_uv_tool_install

# rootless distrobox
fn_local_install_distrobox

# OPA
fn_local_install_opa

# GH cli
fn_local_install_gh

# Task
fn_local_install_task

# yq
fn_local_install_yq

# syft
fn_local_install_syft

# grype
fn_local_install_grype

# cosign
fn_local_install_cosign

# cheat.sh
fn_local_install_chtsh

# aws cli
fn_local_install_aws

# go-blueprint
fn_local_install_go_blueprint

# goose
fn_local_install_goose

# claude code
fn_local_install_claude_code

# charms
fn_local_install_charm_apps

# print errors if there are any
fn_print_errors

printf "Done!\n"
