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

Feel free to read the script if you're curious what it's doing. Otherwise just
run it.

::

    bash ~/dotfiles/bootstrap.sh

Vim
---

For `vim`_ I use the `vimified`_ config distro because it's simple, it does
everything I want, is easy to use, and I'm really lazy.

My modifications to the default vimified setup are are contained in the
``local.vimrc`` and ``after.vimrc`` files in this repository. The following is
how I set it all up including installing `vimified`_, and then symlink these
files into ``~/vimified/``.

I also install `powerline`_'s `patched fonts`_ to supplement the `airline`_
config that comes with vimified.

Again, feel free to read the script if you're curious what it's doing. Otherwise
just run it.

::

    bash ~/dotfiles/bootstrap-vim.sh

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
.. _patched fonts:
    https://powerline.readthedocs.io/en/master/installation/linux.html#fonts-installation
