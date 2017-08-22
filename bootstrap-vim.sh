#!/bin/bash

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

fontdir=$(mktemp -d)
pushd $fontdir
wget https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf
wget https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf
mv PowerlineSymbols.otf ~/.fonts/
fc-cache -vf ~/.fonts/
mkdir -p ~/.config/fontconfig/conf.d/
mv 10-powerline-symbols.conf ~/.config/fontconfig/conf.d/
popd

rm -fr ${fontdir}
