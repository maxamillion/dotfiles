#!/bin/bash
source ./bootstrap-lib.sh
source /etc/os-release

if [[ "${ID}" == "debian" ]]; then
    # local user ssh agent
    fn_local_user_ssh_agent

    fn_system_setup_crostini
fi

if [[ "${ID}" == "redhat" || "${ID}" == "centos" ]]; then 
    fn_system_setup_el
fi

# rustup
fn_local_install_rustup

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

printf "Done!\n"
