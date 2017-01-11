# dotfiles
Small handful of my dotfiles


## Usage

Clone this repo

    cd ~/
    git clone https://github.com/maxamillion/dotfiles.git

Create symlinks so apps can find the dotfiles but they will update on a `git pull`

    # Ensure the needed dirs exist
    mkdir -p ~/.config/{dunst,i3,i3status}
    mkdir ~/.gnupg

    # Symlink the conf files
    ln -s ~/dotfiles/dunstrc ~/.config/dunst/dunstrc
    ln -s ~/dotfiles/i3-config ~/.config/i3/config
    ln -s ~/dotfiles/i3status-config ~/.config/i3status/config
    ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
    ln -s ~/dotfiles/screenrc ~/.screenrc
    ln -s ~/dotfiles/gitconfig ~/.gitconfig
    ln -s ~/dotfiles/inputrc ~/.inputrc
    ln -s ~/dotfiles/bashrc ~/.bashrc


## Vim
For [vim](http://www.vim.org/), I use the
[vimified](https://github.com/zaiste/vimified)
config distro because it's simple, it does everything I want, is easy to use,
and I'm really lazy.

My modifications to the default vimified setup are are contained in the
`local.vimrc` and `after.vimrc` files in this repository. The following is how
I set it all up including installing [vimified](https://github.com/zaiste/vimified),
and then symlink these files into `~/vimified/`.

    cd
    git clone git://github.com/zaiste/vimified.git
    ln -sfn vimified/ ~/.vim
    ln -sfn vimified/vimrc ~/.vimrc
    cd ~/vimified
    mkdir bundle
    mkdir -p tmp/backup tmp/swap tmp/undo
    git clone https://github.com/gmarik/vundle.git bundle/vundle
    ln -s ~/dotfiles/local.vimrc ~/vimified/local.vimrc
    ln -s ~/dotfiles/after.vimrc ~/vimified/after.vimrc
    vim +BundleInstall +qall

I also install [powerline](https://github.com/powerline/powerline)'s [patched
fonts](https://powerline.readthedocs.io/en/master/installation/linux.html#fonts-installation)
to supplement the [airline](https://github.com/vim-airline/vim-airline) config
that comes with vimified.

    cd /tmp/
    wget https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf
    wget https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf
    mv PowerlineSymbols.otf ~/.fonts/
    fc-cache -vf ~/.fonts/
    mkdir -p ~/.config/fontconfig/conf.d/
    mv 10-powerline-symbols.conf ~/.config/fontconfig/conf.d/

## Notes
This repository is more or less meant to be used along with my [workstation
setup](https://github.com/maxamillion/ansible-maxamillion-workstation)
which is configured using [Ansible](https://www.ansible.com/), but if there is
any content here that others might find useful in it's own right then I'm happy
to have shared. :)
