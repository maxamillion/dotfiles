curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &&\
sudo apt install -y nodejs

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

sudo apt install -y vim python3 python3-pip python3-venv

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
