#!/bin/bash

# Strict error handling
set -euo pipefail

# Validate environment
_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
_LIB_FILE="${_SCRIPT_DIR}/bootstrap-lib.sh"

# Source library with error handling
if [[ ! -f "${_LIB_FILE}" ]]; then
    printf "ERROR: Required library file not found: %s" "${_LIB_FILE}" >&2
    exit 1
fi

# shellcheck source=./bootstrap-lib.sh
source "${_LIB_FILE}"

# Check distribution
fn_check_distro

if [[ "${ID}" == "debian" ]]; then
    # local user ssh agent
    fn_local_user_ssh_agent

    fn_system_setup_crostini
    # rustup
    fn_local_install_rustup

    # fn_local_install_neovim
fi

if [[ "${ID}" == "Termux" ]]; then
    fn_system_setup_termux
fi

if [[ "${ID}" == "rhel" || "${ID}" == "redhat" || "${ID}" == "centos" || "${ID}" == "fedora" ]]; then
    fn_system_setup_fedora_el
    # fn_system_install_gcloud

    # virtualenvwrapper
    fn_local_install_virtualenvwrapper

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
fn_local_install_super_claude
#fn_local_install_claude_code_requirements_builder

# gemini cli
fn_local_install_gemini

#amp
fn_local_install_amp_code

# bash language server
fn_local_bash_language_server

# charms
fn_local_install_charm_apps

# print errors if there are any
fn_print_errors

printf "Done!\n"
