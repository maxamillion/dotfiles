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

if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" ]]; then
    fn_system_setup_el
fi

# k8s stuff
fn_local_install_minikube
fn_local_install_kind
fn_local_install_kubectl

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

printf "Done!\n"
