#!/bin/bash
source ./bootstrap-lib.sh

# tailscale
curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
sudo apt update
sudo apt install -y tailscale

# nodejs LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &&\
sudo apt install -y nodejs

# ssh-agent systemd user unit
mkdir_if_needed ~/.config/systemd/user

cat > ~/.config/systemd/user/ssh-agent.service << "EOF"
[Unit]
Description=SSH key agent

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK

[Install]
WantedBy=default.target
EOF

systemctl --user enable ssh-agent

# random dev stuff
sudo apt install -y vim python3 python3-pip python3-venv git tmux htop

python3 -mpip install --user pipx virtualenvwrapper q

pipx install ptpython
pipx install tox
pipx install httpie
pipx install flake8
pipx install pep8
pipx install pyflakes
pipx install pylint
pipx install black
pipx install pipenv
pipx install poetry
pipx install tmuxp
pipx install bpytop
pipx install python-lsp-server
pipx install tldr
