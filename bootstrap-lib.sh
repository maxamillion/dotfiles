#!/bin/bash
#
# Basic library functions for my dotfiles
#

#
# Ensure the needed dirs exist
mkdir_if_needed() {
    if [[ ! -d $1 ]]; then
        mkdir -p $1
    fi
}

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
