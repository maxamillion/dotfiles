#!/bin/bash

set -o vi

export TERM=screen-256color

dnf -y update vim-minimal
dnf -y install vim-enhanced

pip install q

cd ~/

git clone https://github.com/maxamillion/ansible.git
git clone https://github.com/maxamillion/dotfiles.git

~/dotfiles/bootstrap-vim.sh
