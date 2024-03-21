#!/bin/bash
source ./bootstrap-lib.sh
source /etc/os-release

if [[ "${ID}" == "debian" ]]; then
    # local user ssh agent
    local_user_ssh_agent

    system_setup_crostini
fi

if [[ "${ID}" == "redhat" || "${ID}" == "centos" ]]; then 
    system_setup_el
fi

# rustup
local_install_rustup

# k8s stuff
local_install_minikube
local_install_kind
local_install_kubectl

# terraform
local_install_terraform

# pipx
local_pipx_packages_install

# rootless distrobox
local_install_distrobox

# OPA
local_install_opa

# GH cli
local_install_gh

# Neovim
local_install_neovim

# Task
local_install_task

printf "Done!\n"
