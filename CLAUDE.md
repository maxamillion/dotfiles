# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files and bootstrap scripts for GNU/Linux systems.
Specifically this is made to work with Red Hat Enterprise Linux (RHEL), CentOS Stream, Fedora Linux, the debian (crostini)
environment found on Chromebooks, and Termux the Android Linux userspace system.

The repository uses a symlink-based approach to manage dotfiles across the user's home directory.

## Core Commands

### Bootstrap and Setup
- `bash ~/dotfiles/bootstrap.sh` - Main bootstrap script that creates necessary directories and symlinks all dotfiles
- `bash ~/dotfiles/bootstrap-workstation.sh` - Workstation-specific setup (distribution-dependent)
- `bash ~/dotfiles/bootstrap-container-dev.sh` - Container development environment setup
- `bash ~/dotfiles/bootstrap-devel.sh` - Development tools installation

### Key Configuration Files
- `vimrc` - Vim configuration with plugin management via vim-plug
- `init.lua` - Neovim configuration (Lua-based, kickstart.nvim derivative)
- `bashrc`, `bash_profile`, `profile` - Shell configuration
- `tmux.conf` - Terminal multiplexer configuration
- `gitconfig` - Git configuration
- `ssh_config` - SSH client configuration

## Architecture

### Bootstrap System
The bootstrap system is built around a modular design:

1. **bootstrap.sh** - Main entry point that:
   - Sources `bootstrap-lib.sh` for shared functions
   - Creates necessary directories in `~/.config`, `~/.vim`, etc.
   - Creates symlinks from dotfiles to their target locations
   - Calls workstation-specific bootstrap script
   - Sets appropriate file permissions (especially SSH config)

2. **bootstrap-lib.sh** - Shared library providing:
   - Error handling with strict mode (`set -euo pipefail`)
   - Utility functions for directory creation, symlink management
   - Package installation helpers
   - Architecture detection for tool downloads
   - Global arrays for tracking operations

3. **Specialized bootstrap scripts**:
   - `bootstrap-workstation.sh` - Distribution-specific setup
   - `bootstrap-container-dev.sh` - Container development tools
   - `bootstrap-devel.sh` - General development environment

### Editor Configuration
- **Vim**: Uses vim-plug for plugin management, includes plugins for Go, Rust, syntax highlighting, and code completion
- **Neovim**: Lua-based configuration derived from kickstart.nvim with custom keybindings and options
- Both editors share similar philosophy with relative line numbers, undo persistence, and development-focused plugins

### Shell Environment
- Modular shell configuration across `bashrc`, `bash_profile`, and `profile`
- Integration with tmux for terminal multiplexing
- Custom completion and input handling via `inputrc`

## File Organization

Configuration files are stored in repository root and symlinked to their target locations:
- Shell configs → `~/.*rc`, `~/.profile`
- Vim/Neovim → `~/.vimrc`, `~/.config/nvim/init.lua`
- Desktop environment → `~/.config/i3/`, `~/.config/dunst/`
- Development tools → `~/.gitconfig`, `~/.ssh/config`, `~/.tmux.conf`

## Development Workflow

When modifying dotfiles:
1. Edit files directly in the repository
2. Changes are immediately reflected due to symlink structure
3. Use `git pull` to update dotfiles across systems
4. Run appropriate bootstrap script if new files are added

The repository maintains compatibility across different Unix-like systems (Linux distributions, potentially macOS) through conditional logic in bootstrap scripts.
