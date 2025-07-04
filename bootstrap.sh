#!/bin/bash

# Strict error handling
set -euo pipefail

# Validate environment
_DOTFILES_DIR="${HOME}/dotfiles"
_LIB_FILE="${_DOTFILES_DIR}/bootstrap-lib.sh"

# Source library with error handling
if [[ ! -f "${_LIB_FILE}" ]]; then
    echo "ERROR: Required library file not found: ${_LIB_FILE}" >&2
    exit 1
fi

# shellcheck source=./bootstrap-lib.sh
source "${_LIB_FILE}"

# Create necessary directories with absolute paths
fn_mkdir_if_needed "${HOME}/.config/dunst"
fn_mkdir_if_needed "${HOME}/.config/i3"
fn_mkdir_if_needed "${HOME}/.config/i3status"
fn_mkdir_if_needed "${HOME}/.config/fontconfig"
fn_mkdir_if_needed "${HOME}/.config/fontconfig/conf.d"
#fn_mkdir_if_needed "${HOME}/.config/nvim/lua/"
fn_mkdir_if_needed "${HOME}/.tmuxinator"
fn_mkdir_if_needed "${HOME}/.ptpython"
fn_mkdir_if_needed "${HOME}/.fonts"
fn_mkdir_if_needed "${HOME}/.ssh"
fn_mkdir_if_needed "${HOME}/.vimundo"
fn_mkdir_if_needed "${HOME}/.vim"
fn_mkdir_if_needed "${HOME}/.ipython/profile_default/"
fn_mkdir_if_needed "${HOME}/.shelloracle/"

# Create symlinks with absolute paths
fn_symlink_if_needed "${_DOTFILES_DIR}/snclirc"            "${HOME}/.snclirc"
fn_symlink_if_needed "${_DOTFILES_DIR}/dunstrc"            "${HOME}/.config/dunst/dunstrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/i3-config"          "${HOME}/.config/i3/config"
fn_symlink_if_needed "${_DOTFILES_DIR}/i3status-config"    "${HOME}/.config/i3status/config"
fn_symlink_if_needed "${_DOTFILES_DIR}/redshift.conf"      "${HOME}/.config/redshift.conf"
fn_symlink_if_needed "${_DOTFILES_DIR}/tmux.conf"          "${HOME}/.tmux.conf"
fn_symlink_if_needed "${_DOTFILES_DIR}/tmuxp.yml"          "${HOME}/.tmuxp.yml"
fn_symlink_if_needed "${_DOTFILES_DIR}/tmuxinator-wm.yml"  "${HOME}/.tmuxinator/wm.yml"
fn_symlink_if_needed "${_DOTFILES_DIR}/screenrc"           "${HOME}/.screenrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/gitconfig"          "${HOME}/.gitconfig"
fn_symlink_if_needed "${_DOTFILES_DIR}/inputrc"            "${HOME}/.inputrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/ptpython_config.py" "${HOME}/.ptpython/config.py"
fn_symlink_if_needed "${_DOTFILES_DIR}/ssh_config"         "${HOME}/.ssh/config"
fn_symlink_if_needed "${_DOTFILES_DIR}/Xresources"         "${HOME}/.Xresources"
fn_symlink_if_needed "${_DOTFILES_DIR}/bashrc"             "${HOME}/.bashrc"
fn_symlink_if_needed "${_DOTFILES_DIR}/bash_profile"       "${HOME}/.bash_profile"
fn_symlink_if_needed "${_DOTFILES_DIR}/profile"            "${HOME}/.profile"
fn_symlink_if_needed "${_DOTFILES_DIR}/vimrc"              "${HOME}/.vimrc"
#fn_symlink_if_needed "${_DOTFILES_DIR}/coc-settings.json"  "${HOME}/.vim/coc-settings.json"
#fn_symlink_if_needed "${_DOTFILES_DIR}/init.lua"           "${HOME}/.config/nvim/init.lua"
fn_symlink_if_needed "${_DOTFILES_DIR}/ipython_config.py"  "${HOME}/ipython/profile_default/ipython_config.py"
fn_symlink_if_needed "${_DOTFILES_DIR}/myhosts"            "${HOME}/.myhosts"
fn_symlink_if_needed "${_DOTFILES_DIR}/shelloracle-config.toml" "${HOME}/.shelloracle/config.toml"

# Run workstation-specific bootstrap
_WORKSTATION_SCRIPT="${_DOTFILES_DIR}/bootstrap-workstation.sh"
if [[ -f "${_WORKSTATION_SCRIPT}" ]]; then
    "${_WORKSTATION_SCRIPT}" || fn_log_error "bootstrap-workstation.sh failed"
else
    fn_log_error "bootstrap-workstation.sh not found: ${_WORKSTATION_SCRIPT}"
fi

# This doesn't appear to be necessary, but keep it around just in case
#link_if_needed "${_DOTFILES_DIR}/sshrc" "${HOME}/.ssh/rc"

# Set secure permissions on SSH config
_SSH_CONFIG="${_DOTFILES_DIR}/ssh_config"
if [[ -f "${_SSH_CONFIG}" ]]; then
    chmod 0600 "${_SSH_CONFIG}" || fn_log_error "Failed to set permissions on ${_SSH_CONFIG}"
else
    fn_log_error "SSH config file not found: ${_SSH_CONFIG}"
fi
