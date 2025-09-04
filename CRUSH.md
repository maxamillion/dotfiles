# CRUSH.md

This file provides guidance to autonomous agents for working with this dotfiles repository.

## Repository Overview

This is a personal dotfiles repository for GNU/Linux systems (RHEL, Fedora, Debian, etc.). It uses a symlink-based approach to manage configurations. The main language is Bash for scripting, with Lua for Neovim configuration.

## Core Commands

- **Bootstrap:** `bash ~/dotfiles/bootstrap.sh` is the main entry point for setup.
- **Specialized Setups:**
  - `bash ~/dotfiles/bootstrap-workstation.sh`
  - `bash ~/dotfiles/bootstrap-container-dev.sh`
  - `bash ~/dotfiles/bootstrap-devel.sh`

There are no dedicated build, test, or lint commands. Validation is typically done by sourcing the shell scripts or running the bootstrap scripts.

## Code Style & Conventions

- **Shell Scripting (Bash):**
  - **Strict Mode:** Scripts must use `set -euo pipefail`.
  - **Error Handling:** Check for command success and handle errors appropriately.
  - **Functions:** Use shared functions from `bootstrap-lib.sh`.
  - **Compatibility:** Maintain compatibility across different Linux distributions.
- **Vim/Neovim:**
  - **Vim:** `vimrc` with vim-plug for plugins.
  - **Neovim:** `init.lua` (Lua-based), derivative of kickstart.nvim.
- **Git:**
  - **Commit Messages:** Follow conventional commit standards (e.g., `feat:`, `fix:`, `docs:`).
- **General:**
  - New configurations should be added to the repository and symlinked by `bootstrap.sh`.
  - Changes should be tested by applying them and ensuring the relevant applications (shell, vim, etc.) work as expected.
