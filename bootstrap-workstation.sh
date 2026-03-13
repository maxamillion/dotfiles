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
 
    # virtualenvwrapper
    fn_local_install_virtualenvwrapper

fi

# Only setup gcloud if inside a Fedora toolbox
if [[ "${ID}" == "fedora" ]] && ! [[ -z "${TOOLBOX_PATH:-}" ]]; then
    fn_system_install_gcloud
fi

# setup vim plug
fn_local_install_vim_plug

# uv tool install
fn_local_uv_tool_install

# rootless distrobox
fn_local_install_distrobox

# cheat.sh
fn_local_install_chtsh

# aws cli
fn_local_install_aws

# bin (binary manager) - must come before fn_local_install_bin_apps
fn_local_install_bin

# all bin-managed apps (k8s, security, dev tools, charm apps, etc.)
fn_local_install_bin_apps

# claude code
fn_local_install_claude_code
fn_local_install_super_claude
#fn_local_install_claude_code_requirements_builder

# openai codex
fn_local_install_openai_codex

# gemini cli
fn_local_install_gemini

# bash language server
fn_local_bash_language_server

# print errors if there are any
fn_print_errors

printf "Done!\n"
