#!/bin/bash

source ./bootstrap-lib.sh

mkdir_if_needed ~/.config/{dunst,i3,i3status,fontconfig}
mkdir_if_needed ~/.config/fontconfig/conf.d
mkdir_if_needed ~/.config/nvim/lua/
mkdir_if_needed ~/.tmuxinator
mkdir_if_needed ~/.ptpython
mkdir_if_needed ~/.fonts
mkdir_if_needed ~/.ssh
mkdir_if_needed ~/.vimundo
mkdir_if_needed ~/.vim
mkdir_if_needed ~/.ipython/profile_default/

symlink_if_needed ~/dotfiles/snclirc            ~/.snclirc
symlink_if_needed ~/dotfiles/dunstrc            ~/.config/dunst/dunstrc
symlink_if_needed ~/dotfiles/i3-config          ~/.config/i3/config
symlink_if_needed ~/dotfiles/i3status-config    ~/.config/i3status/config
symlink_if_needed ~/dotfiles/redshift.conf      ~/.config/redshift.conf
symlink_if_needed ~/dotfiles/tmux.conf          ~/.tmux.conf
symlink_if_needed ~/dotfiles/tmuxp.yml          ~/.tmuxp.yml
symlink_if_needed ~/dotfiles/tmuxinator-wm.yml  ~/.tmuxinator/wm.yml
symlink_if_needed ~/dotfiles/screenrc           ~/.screenrc
symlink_if_needed ~/dotfiles/gitconfig          ~/.gitconfig
symlink_if_needed ~/dotfiles/inputrc            ~/.inputrc
symlink_if_needed ~/dotfiles/ptpython_config.py ~/.ptpython/config.py
symlink_if_needed ~/dotfiles/ssh_config         ~/.ssh/config
symlink_if_needed ~/dotfiles/Xresources         ~/.Xresources
symlink_if_needed ~/dotfiles/bashrc             ~/.bashrc
symlink_if_needed ~/dotfiles/profile            ~/.profile
symlink_if_needed ~/dotfiles/vimrc              ~/.vimrc
symlink_if_needed ~/dotfiles/coc-settings.json  ~/.vim/coc-settings.json
symlink_if_needed ~/dotfiles/init.lua           ~/.config/nvim/init.lua
symlink_if_needed ~/dotfiles/ipython_config.py  ~/ipython/profile_default/ipython_config.py

./bootstrap-workstation.sh

if [[ ! -f ~/.vim/autoload/plug.vim ]]; then
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim;
    vim +'PlugInstall!' +qall
    vim +'CocInstall coc-json coc-sh coc-tsserver coc-pyright @yaegassy/coc-ansible coc-go coc-rust-analyzer coc-yaml' +qall
fi

# This doesn't appear to be necessary, but keep it around just in case
#link_if_needed ~/dotfiles/sshrc ~/.ssh/rc

# Set perms on ~/.ssh/config
chmod 0600 ~/dotfiles/ssh_config
