#!/bin/bash

# Ensure the needed dirs exist
mkdir -p ~/.config/{dunst,i3,i3status,fontconfig}
mkdir -p ~/.config/fontconfig/conf.d
mkdir ~/.tmuxinator
mkdir ~/.ptpython
mkdir ~/.fonts
mkdir ~/.ssh/

# Symlink the conf files
ln -s ~/dotfiles/dunstrc ~/.config/dunst/dunstrc
ln -s ~/dotfiles/i3-config ~/.config/i3/config
ln -s ~/dotfiles/i3status-config ~/.config/i3status/config
ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/dotfiles/tmuxinator-wm.yml ~/.tmuxinator/wm.yml
ln -s ~/dotfiles/screenrc ~/.screenrc
ln -s ~/dotfiles/gitconfig ~/.gitconfig
ln -s ~/dotfiles/inputrc ~/.inputrc
ln -s ~/dotfiles/ptpython_config.py ~/.ptpython/config.py
ln -s ~/dotfiles/ssh_config ~/.ssh/config
ln -s ~/dotfiles/bashrc ~/.bashrc

# Set perms on ~/.ssh/config
chmod 0600 ~/dotfiles/ssh_config
restorecon -Rvv ~/.ssh
