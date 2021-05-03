#!/bin/bash

# Ensure the needed dirs exist
mkdir_if_needed() {
    if [[ ! -d $1 ]]; then
        mkdir -p $1
    fi
}

mkdir_if_needed ~/.config/{dunst,i3,i3status,fontconfig}
mkdir_if_needed ~/.config/fontconfig/conf.d
mkdir_if_needed ~/.tmuxinator
mkdir_if_needed ~/.ptpython
mkdir_if_needed ~/.fonts
mkdir_if_needed ~/.ssh
mkdir_if_needed ~/.vimundo

# Symlink the conf files
symlink_if_needed() {
    if [[ ! -f $2 ]] && [[ ! -L $2 ]]; then
        printf "Symlinking: %s -> %s\n" "$1" "$2"
        if [[ ! -d $(dirname $2) ]]; then
            mkdir -p $(dirname $2)
        fi
        ln -s $1 $2
    fi
    if [[ -f $2 ]] && [[ ! -L $2 ]]; then
        printf "File found: %s\n" "$2"
    fi
}
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

if [[ ! -f ~/.vim/autoload/plug.vim ]]; then
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim;
    vim +PlugInstall! +qall
fi

# This doesn't appear to be necessary, but keep it around just in case
#link_if_needed ~/dotfiles/sshrc ~/.ssh/rc

# Set perms on ~/.ssh/config
chmod 0600 ~/dotfiles/ssh_config
