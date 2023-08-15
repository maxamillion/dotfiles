#!/bin/bash
source ./bootstrap-lib.sh

# tailscale
curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
sudo apt update
sudo apt install -y tailscale

# docker - because podman doesn't work in crostini/termina
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker $USER

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
sudo apt install -y vim python3 python3-pip python3-venv git tmux htop strace

# download golang
golang_version="1.20.7"
sudo apt remove -y golang 
if [[ -d /usr/local/go ]]; then
    sudo rm -fr /usr/local/go
fi
sudo curl -o "/usr/local/go-${golang_version}.tar.gz" "https://dl.google.com/go/go${golang_version}.linux-$(dpkg --print-architecture).tar.gz"
sudo tar -zxvf /usr/local/go-${golang_version}.tar.gz --directory=/usr/local/
sudo rm /usr/local/go-${golang_version}.tar.gz

python3 -mpip install --user pipx virtualenvwrapper q

for pypkg in ptpython tox httpie flake8 pep8 pyflakes pylint black pipenv poetry tmuxp bpytop python-lsp-server tldr
do
    pipx install ${pypkg}
done
