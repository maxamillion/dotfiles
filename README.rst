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


Notes
-----

This repository is more or less meant to be used along with my `workstation
setup`_ which is configured using `Ansible`_, but if there is any content here
that others might find useful in it's own right then I'm happy to have shared.
:)

.. _vim: http://www.vim.org/
.. _Ansible: https://www.ansible.com/
.. _airline: https://github.com/vim-airline/vim-airline
.. _workstation setup: https://github.com/maxamillion/maxible
.. _patched fonts:
    https://powerline.readthedocs.io/en/master/installation/linux.html#fonts-installation
