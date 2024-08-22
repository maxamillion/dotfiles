#!/bin/bash
source ./bootstrap-lib.sh
source /etc/os-release

if [[ "${ID}" == "debian" ]]; then
    # local user ssh agent
    fn_local_user_ssh_agent

    fn_system_setup_crostini
    # rustup
    fn_local_install_rustup
fi

if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || ${ID} == "fedora" ]]; then
    fn_system_setup_fedora_el

    # virtualenvwrapper
    fn_local_install_virtualenvwrapper

fi

# k8s stuff
fn_local_install_minikube
fn_local_install_kind
fn_local_install_kubectl
fn_local_install_k9s

# rosa
fn_local_install_rosa

# terraform
fn_local_install_terraform

# pipx
fn_local_pipx_packages_install

# rootless distrobox
fn_local_install_distrobox

# OPA
fn_local_install_opa

# GH cli
fn_local_install_gh

# Neovim
fn_local_install_neovim

# Task
fn_local_install_task

# yq
fn_local_install_yq

# ollama
fn_local_install_ollama

# syft
fn_local_install_syft

# print errors if there are any
fn_print_errors

printf "Done!\n"
