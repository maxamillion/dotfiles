#!/bin/bash

source ./bootstrap-lib.sh

fn_mkdir_if_needed ~/.config/{dunst,i3,i3status,fontconfig}
fn_mkdir_if_needed ~/.config/fontconfig/conf.d
fn_mkdir_if_needed ~/.config/nvim/lua/
fn_mkdir_if_needed ~/.tmuxinator
fn_mkdir_if_needed ~/.ptpython
fn_mkdir_if_needed ~/.fonts
fn_mkdir_if_needed ~/.ssh
fn_mkdir_if_needed ~/.vimundo
fn_mkdir_if_needed ~/.vim
fn_mkdir_if_needed ~/.ipython/profile_default/

fn_symlink_if_needed ~/dotfiles/snclirc            ~/.snclirc
fn_symlink_if_needed ~/dotfiles/dunstrc            ~/.config/dunst/dunstrc
fn_symlink_if_needed ~/dotfiles/i3-config          ~/.config/i3/config
fn_symlink_if_needed ~/dotfiles/i3status-config    ~/.config/i3status/config
fn_symlink_if_needed ~/dotfiles/redshift.conf      ~/.config/redshift.conf
fn_symlink_if_needed ~/dotfiles/tmux.conf          ~/.tmux.conf
fn_symlink_if_needed ~/dotfiles/tmuxp.yml          ~/.tmuxp.yml
fn_symlink_if_needed ~/dotfiles/tmuxinator-wm.yml  ~/.tmuxinator/wm.yml
fn_symlink_if_needed ~/dotfiles/screenrc           ~/.screenrc
fn_symlink_if_needed ~/dotfiles/gitconfig          ~/.gitconfig
fn_symlink_if_needed ~/dotfiles/inputrc            ~/.inputrc
fn_symlink_if_needed ~/dotfiles/ptpython_config.py ~/.ptpython/config.py
fn_symlink_if_needed ~/dotfiles/ssh_config         ~/.ssh/config
fn_symlink_if_needed ~/dotfiles/Xresources         ~/.Xresources
fn_symlink_if_needed ~/dotfiles/bashrc             ~/.bashrc
fn_symlink_if_needed ~/dotfiles/profile            ~/.profile
fn_symlink_if_needed ~/dotfiles/vimrc              ~/.vimrc
fn_symlink_if_needed ~/dotfiles/coc-settings.json  ~/.vim/coc-settings.json
fn_symlink_if_needed ~/dotfiles/init.lua           ~/.config/nvim/init.lua
fn_symlink_if_needed ~/dotfiles/ipython_config.py  ~/ipython/profile_default/ipython_config.py

./bootstrap-workstation.sh

# This doesn't appear to be necessary, but keep it around just in case
#link_if_needed ~/dotfiles/sshrc ~/.ssh/rc

# Set perms on ~/.ssh/config
chmod 0600 ~/dotfiles/ssh_config
