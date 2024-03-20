#!/bin/bash
#
# Basic library functions for my dotfiles
#

_MACHINE_ARCH=$(uname -m)

# pipx install pypkglist 
_PIPX_PACKAGE_LIST=(
    "ptpython"
    "tox"
    "httpie"
    "flake8"
    "pep8"
    "pyflakes"
    "pylint"
    "black"
    "pipenv"
    "poetry"
    "tmuxp"
    "bpytop"
    "python-lsp-server"
    "tldr"
    "nodeenv"
)

if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
    _GOLANG_ARCH="amd64"
fi
if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
    _GOLANG_ARCH="arm64"
fi
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

local_user_ssh_agent() {
    # ssh-agent systemd user unit
    mkdir_if_needed ~/.config/systemd/user

    if [[ ! -f ~/.config/systemd/user/ssh-agent.service ]]; then
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
    fi
}

local_install_distrobox() {
    local install_path="${HOME}/.local/bin/distrobox"
    local distrobox_version="$(curl -s 'https://api.github.com/repos/89luca89/distrobox/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            local currently_installed_version=$(distrobox version | awk -F: '/^distrobox/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            if [[ ${distrobox_version} != "${currently_installed_version}" ]]; then
                rm -f ${install_path}
                rm -f "${install_path}-*"
            fi
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
    fi
}

local_install_opa() {
    local install_path="${HOME}/.local/bin/opa"
    local opa_version="$(curl -s 'https://api.github.com/repos/open-policy-agent/opa/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            local currently_installed_version=$(opa version | awk -F: '/^Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            if [[ ${opa_version} != "v${currently_installed_version}" ]]; then
                rm -f ${install_path}
            fi
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
            curl -L -o ${install_path} https://openpolicyagent.org/downloads/${opa_version}/opa_linux_amd64_static
        fi  
        if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
            curl -L -o ${install_path} https://openpolicyagent.org/downloads/${opa_version}/opa_linux_arm64_static
        fi  
        chmod +x ${install_path}
    fi
}

local_install_minikube() {
    local install_path="${HOME}/.local/bin/minikube"
    local minikube_version="$(curl -s 'https://api.github.com/repos/kubernetes/minikube/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            local currently_installed_version=$(minikube version | awk -F: '/^minikube version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            if [[ ${minikube_version} != "${currently_installed_version}" ]]; then
                rm -f ${install_path}
            fi
        fi
    fi

    # minikube install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing minikube...\n"
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${_GOLANG_ARCH}
        chmod +x ./minikube-linux-${_GOLANG_ARCH}
        sudo mv ./minikube-linux-${_GOLANG_ARCH} ${install_path}
    fi
}

local_install_kind() {
    local install_path="${HOME}/.local/bin/kind"
    # kind tags alpha and stable, if it's alpha, use the latest stable - query with jq
    local kind_version="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kind/tags' | jq -r '.[] | select(.name | contains("alpha") | not ).name' | head -1)"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            local currently_installed_version=$(kind version | awk '/^kind/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            if [[ ${kind_version} != "${currently_installed_version}" ]]; then
                rm -f ${install_path}
            fi
        fi
    fi

    kind_numerical_version="${kind_version#v*}"

    # kind install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kind...\n"
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-${_GOLANG_ARCH}"
        chmod +x ./kind
        mv ./kind ${install_path}
    fi
}

local_install_kubectl() {
    local install_path="${HOME}/.local/bin/kubectl"
    local kubectl_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            local currently_installed_version=$(kubectl version 2>/dev/null | awk -F: '/^Client Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            if [[ ${kubectl_version} != "${currently_installed_version}" ]]; then
                rm -f ${install_path}
            fi
        fi
    fi

    # kubectl install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kubectl...\n"
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${_GOLANG_ARCH}/kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl ${install_path}
    fi
}

local_install_terraform() {
    local install_path="${HOME}/.local/bin/terraform"

    # terraform tags alpha, beta, and rc ... don't get those
    local terraform_vprefix_version="$(
        curl -s 'https://api.github.com/repos/hashicorp/terraform/tags' \
            | jq -r '.[] | select(.name | contains("alpha") | not )| select(.name | contains("beta") | not ) | select(.name | contains("rc") | not).name' \
            | head -1 \
    )"

    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            local currently_installed_version=$(terraform version | awk '/^Terraform/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            if [[ ${terraform_vprefix_version} != "${currently_installed_version}" ]]; then
                rm -f ${install_path}
            fi
        fi
    fi

    local terraform_version="${terraform_vprefix_version#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing terraform...\n"
        printf "curl -Lo ${install_path} https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${_GOLANG_ARCH}.zip\n"
        pushd /tmp/
            rm -f terraform terraform.zip # just to make sure the zip command doesn't complain
            curl -Lo terraform.zip \
                https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${_GOLANG_ARCH}.zip
            unzip terraform.zip
            cp terraform ${install_path}
        popd
        chmod +x ${install_path}
    fi
}

local_install_rustup() {
    local install_path="${HOME}/.cargo/bin/rustup"
    local rustup_version="$(curl -s 'https://api.github.com/repos/open-policy-agent/opa/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        if [[ -f ${install_path} ]]; then
            local currently_installed_version=$(rustup --version| awk '/^rustup/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
            if [[ ${rustup_version} != "${currently_installed_version}" ]]; then
                rm -f ${install_path}
            fi
        fi
    fi

    if [[ ! -f ${install_path} ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    fi
}

local_install_gh() {
    local install_path="${HOME}/.local/bin/gh"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    local gh_version="$(curl -s 'https://api.github.com/repos/cli/cli/tags' | jq -r '.[0].name')"
    local gh_numerical_version="${gh_version#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing gh...\n"
        curl -Lo /tmp/gh.tar.gz https://github.com/cli/cli/releases/download/${gh_version}/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}.tar.gz
        tar -zxvf /tmp/gh.tar.gz -C /tmp/
        cp /tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/bin/gh ${install_path}
        cp /tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/share/man/man1/* ${HOME}/.local/share/man/man1/
    fi
}

local_install_neovim() {
    local install_path="${HOME}/.local/bin/nvim"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
    fi

    local neovim_version="$(curl -s 'https://api.github.com/repos/neovim/neovim/tags' | jq -r '.[0].name')"
    local neovim_numerical_version="${neovim_version#v*}"


    if [[ ! -f ${install_path} ]]; then
        printf "Installing neovim from source ... \n"

        pushd /tmp/
            wget -c https://github.com/neovim/neovim/archive/refs/tags/${neovim_version}.tar.gz
            tar -zxvf ${neovim_version}.tar.gz
            pushd neovim-${neovim_numerical_version}/
                make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=${HOME}/.local/
                make install
            popd
            rm -fr neovim-${neovim_version}/
        popd
    fi



}

local_install_task() {
    local install_path="${HOME}/.local/bin/task"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/task"
    if [[ ${1} == "update" ]]; then
        rm -f ${install_path}
        rm -f ${completions_install_path}
    fi


    local task_version="$(curl -s 'https://api.github.com/repos/go-task/task/tags' | jq -r '.[0].name')"
    local task_numerical_version="${task_version#v*}"

    if [[ ! -f ${install_path} ]]; then
        printf "Installing task...\n"

        pushd /tmp/
            wget -c https://github.com/go-task/task/releases/download/${task_version}/task_linux_${_GOLANG_ARCH}.tar.gz
            tar -zxvf task_linux_${_GOLANG_ARCH}.tar.gz
            cp task ${install_path}
            cp completion/bash/task.bash ${completions_install_path}

            # cleanup the tarball artifacts
            for file in $(tar --list --file task_linux_${_GOLANG_ARCH}.tar.gz); do
                rm -f ${file}
            done
            rm -fr completion
    fi
}


local_pipx_packages_install() {
    if which pipx > /dev/null 2>&1; then
        for pypkg in ${_PIPX_PACKAGE_LIST[@]};
        do
            if [[ ! -d ${HOME}/.local/pipx/venvs/${pypkg} ]]; then
                pipx install ${pypkg}
            fi
        done
    fi
}

update_local_installs() {
    local_install_distrobox update
    local_install_opa update
    local_install_minikube update
    local_install_kind update
    local_install_kubectl update
    local_install_terraform update
    local_install_rustup update
    local_install_gh update
    local_install_neovim update
    pipx upgrade-all
}
