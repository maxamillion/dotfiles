# dotfiles
Small handful of my dotfiles

## Usage

Clone this repo

    cd ~/
    git clone https://github.com/maxamillion/dotfiles.git

Create symlinks so apps can find the dotfiles but they will update on a `git pull`

    ln -s ~/dotfiles/dunstrc ~/.config/dunst/dunstrc
    ln -s ~/dotfiles/i3-config ~/.config/i3/config
    ln -s ~/dotfiles/i3status-config ~/.config/i3status/config
    ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
    ln -s ~/dotfiles/gitconfig ~/.gitconfig
    ln -s ~/dotfiles/inputrc ~/.inputrc
    ln -s ~/dotfiles/bashrc ~/.bashrc

## Notes

This does not cover [vim](http://www.vim.org/), I use [spf13](https://github.com/spf13/)'s 
[vim.spf13](http://vim.spf13.com/) config distro because it's really nice, it does everything
I want, is really easy to use and I'm really lazy.
