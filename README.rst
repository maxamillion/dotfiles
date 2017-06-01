dotfiles
========

Small handful of my dotfiles


Usage
-----

Clone this repo

::

    cd ~/
    git clone https://github.com/maxamillion/dotfiles.git

Create symlinks so apps can find the dotfiles but they will update on a ``git
pull``

::

    # Ensure the needed dirs exist
    mkdir -p ~/.config/{dunst,i3,i3status,fontconfig}
    mkdir -p ~/.config/fontconfig/conf.d
    mkdir ~/.ptpython
    mkdir ~/.fonts
    mkdir ~/.SpaceVim.d/

    # Symlink the conf files
    ln -s ~/dotfiles/dunstrc ~/.config/dunst/dunstrc
    ln -s ~/dotfiles/i3-config ~/.config/i3/config
    ln -s ~/dotfiles/i3status-config ~/.config/i3status/config
    ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
    ln -s ~/dotfiles/screenrc ~/.screenrc
    ln -s ~/dotfiles/gitconfig ~/.gitconfig
    ln -s ~/dotfiles/inputrc ~/.inputrc
    ln -s ~/dotfiles/ptpython_config.py ~/.ptpython/config.py
    ln -s ~/dotfiles/bashrc ~/.bashrc


Vim
---

For `vim`_ I use the `SpaceVim`_ config distro.

My modifications to the default SpaceVim setup are are contained in the
``SpaceVim-init.vim`` file in this repository.

The following is how I set it all up including installing `SpaceVim`_, and then 
symlink my config file into ``~/.SpaceVim.d/``.

::

    cd
    curl -sLf https://spacevim.org/install.sh | bash -s -- install vim
    ln -s ~/dotfiles/SpaceVim-init.vim ~/.SpaceVim.d/init.vim
    

I also install `powerline`_'s `patched fonts`_ to supplement the `airline`_
config that comes with SpaceVim.

::

    cd /tmp/
    wget https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf
    wget https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf
    mv PowerlineSymbols.otf ~/.fonts/
    fc-cache -vf ~/.fonts/
    mkdir -p ~/.config/fontconfig/conf.d/
    mv 10-powerline-symbols.conf ~/.config/fontconfig/conf.d/

Notes
-----

This repository is more or less meant to be used along with my `workstation
setup`_ which is configured using `Ansible`_, but if there is any content here
that others might find useful in it's own right then I'm happy to have shared.
:)

.. _vim: http://www.vim.org/
.. _Ansible: https://www.ansible.com/
.. _vimified: https://github.com/zaiste/vimified
.. _powerline: https://github.com/powerline/powerline
.. _airline: https://github.com/vim-airline/vim-airline
.. _workstation setup: https://github.com/maxamillion/maxible
.. _SpaceVim: http://spacevim.org/
.. _patched fonts:
    https://powerline.readthedocs.io/en/master/installation/linux.html#fonts-installation
