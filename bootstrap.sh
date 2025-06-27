#!/bin/bash

# Strict error handling
set -euo pipefail

# Validate environment
readonly _SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly _LIB_FILE="${_SCRIPT_DIR}/bootstrap-lib.sh"

# Source library with error handling
if [[ ! -f "${_LIB_FILE}" ]]; then
    echo "ERROR: Required library file not found: ${_LIB_FILE}" >&2
    exit 1
fi

# shellcheck source=./bootstrap-lib.sh
source "${_LIB_FILE}"

# Create necessary directories with absolute paths
readonly _HOME_DIR="${HOME}"
fn_mkdir_if_needed "${_HOME_DIR}/.config/dunst"
fn_mkdir_if_needed "${_HOME_DIR}/.config/i3"
fn_mkdir_if_needed "${_HOME_DIR}/.config/i3status"
fn_mkdir_if_needed "${_HOME_DIR}/.config/fontconfig"
fn_mkdir_if_needed "${_HOME_DIR}/.config/fontconfig/conf.d"
#fn_mkdir_if_needed "${_HOME_DIR}/.config/nvim/lua/"
fn_mkdir_if_needed "${_HOME_DIR}/.tmuxinator"
fn_mkdir_if_needed "${_HOME_DIR}/.ptpython"
fn_mkdir_if_needed "${_HOME_DIR}/.fonts"
fn_mkdir_if_needed "${_HOME_DIR}/.ssh"
fn_mkdir_if_needed "${_HOME_DIR}/.vimundo"
fn_mkdir_if_needed "${_HOME_DIR}/.vim"
fn_mkdir_if_needed "${_HOME_DIR}/.ipython/profile_default/"
fn_mkdir_if_needed "${_HOME_DIR}/.shelloracle/"

# Create symlinks with absolute paths
readonly _DOTFILES_DIR="${_SCRIPT_DIR}"
fn_symlink_if_needed "${_DOTFILES_DIR}/snclirc"            "${_HOME_DIR}/.snclirc"
fn_symlink_if_needed "${_DOTFILES_DIR}/dunstrc"            "${_HOME_DIR}/.config/dunst/dunstrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/i3-config"          "${_HOME_DIR}/.config/i3/config"
fn_symlink_if_needed "${_DOTFILES_DIR}/i3status-config"    "${_HOME_DIR}/.config/i3status/config"
fn_symlink_if_needed "${_DOTFILES_DIR}/redshift.conf"      "${_HOME_DIR}/.config/redshift.conf"
fn_symlink_if_needed "${_DOTFILES_DIR}/tmux.conf"          "${_HOME_DIR}/.tmux.conf"
fn_symlink_if_needed "${_DOTFILES_DIR}/tmuxp.yml"          "${_HOME_DIR}/.tmuxp.yml"
fn_symlink_if_needed "${_DOTFILES_DIR}/tmuxinator-wm.yml"  "${_HOME_DIR}/.tmuxinator/wm.yml"
fn_symlink_if_needed "${_DOTFILES_DIR}/screenrc"           "${_HOME_DIR}/.screenrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/gitconfig"          "${_HOME_DIR}/.gitconfig"
fn_symlink_if_needed "${_DOTFILES_DIR}/inputrc"            "${_HOME_DIR}/.inputrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/ptpython_config.py" "${_HOME_DIR}/.ptpython/config.py"
fn_symlink_if_needed "${_DOTFILES_DIR}/ssh_config"         "${_HOME_DIR}/.ssh/config"
fn_symlink_if_needed "${_DOTFILES_DIR}/Xresources"         "${_HOME_DIR}/.Xresources"
fn_symlink_if_needed "${_DOTFILES_DIR}/bashrc"             "${_HOME_DIR}/.bashrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/bash_profile"       "${_HOME_DIR}/.bash_profile"
fn_symlink_if_needed "${_DOTFILES_DIR}/profile"            "${_HOME_DIR}/.profile"
fn_symlink_if_needed "${_DOTFILES_DIR}/vimrc"              "${_HOME_DIR}/.vimrc"
#fn_symlink_if_needed "${_DOTFILES_DIR}/coc-settings.json"  "${_HOME_DIR}/.vim/coc-settings.json"
#fn_symlink_if_needed "${_DOTFILES_DIR}/init.lua"           "${_HOME_DIR}/.config/nvim/init.lua"
fn_symlink_if_needed "${_DOTFILES_DIR}/ipython_config.py"  "${_HOME_DIR}/ipython/profile_default/ipython_config.py"
fn_symlink_if_needed "${_DOTFILES_DIR}/myhosts"            "${_HOME_DIR}/.myhosts"
fn_symlink_if_needed "${_DOTFILES_DIR}/shelloracle-config.toml" "${_HOME_DIR}/.shelloracle/config.toml"

# Run workstation-specific bootstrap
readonly WORKSTATION_SCRIPT="${_SCRIPT_DIR}/bootstrap-workstation.sh"
if [[ -f "${WORKSTATION_SCRIPT}" ]]; then
    "${WORKSTATION_SCRIPT}" || fn_log_error "bootstrap-workstation.sh failed"
else
    fn_log_error "bootstrap-workstation.sh not found: ${WORKSTATION_SCRIPT}"
fi

# This doesn't appear to be necessary, but keep it around just in case
#link_if_needed "${_DOTFILES_DIR}/sshrc" "${_HOME_DIR}/.ssh/rc"

# Set secure permissions on SSH config
readonly SSH_CONFIG="${_DOTFILES_DIR}/ssh_config"
if [[ -f "${SSH_CONFIG}" ]]; then
    chmod 0600 "${SSH_CONFIG}" || fn_log_error "Failed to set permissions on ${SSH_CONFIG}"
else
    fn_log_error "SSH config file not found: ${SSH_CONFIG}"
fi
