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

## Vim
For [vim](http://www.vim.org/), I use the
[vimified](https://github.com/zaiste/vimified)
config distro because it's simple, it does everything I want, is easy to use,
and I'm really lazy.

My modifications to the default vimified setup are are contained in the
`local.vimrc` and `after.vimrc` files in this repository. After you have
installed [vimified](https://github.com/zaiste/vimified), symlink these files
into `~/vimified/`.

    ln -s ~/dotfiles/local.vimrc ~/vimified/local.vimrc
    ln -s ~/dotfiles/after.vimrc ~/vimified/after.vimrc


## Notes
This repository is more or less meant to be used along with my [workstation
setup](https://github.com/maxamillion/ansible-maxamillion-workstation)
which is configured using [Ansible](https://www.ansible.com/), but if there is
any content here that others might find useful in it's own right then I'm happy
to have shared. :)
