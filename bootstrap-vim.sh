#!/bin/bash

#cd $HOME
#git clone git://github.com/zaiste/vimified.git
#ln -sfn vimified/ ~/.vim
#ln -sfn vimified/vimrc ~/.vimrc
#cd ~/vimified
#mkdir bundle
#mkdir -p tmp/backup tmp/swap tmp/undo
#git clone https://github.com/gmarik/vundle.git bundle/vundle
#ln -s ~/dotfiles/local.vimrc ~/vimified/local.vimrc
#ln -s ~/dotfiles/after.vimrc ~/vimified/after.vimrc
#vim +BundleInstall +qall

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim



