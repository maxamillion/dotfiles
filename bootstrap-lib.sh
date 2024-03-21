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
    if [[ ! -d "${1}" ]]; then
        mkdir -p "${1}"
    fi
}

# Symlink the conf files
symlink_if_needed() {
    if [[ ! -f $2 ]] && [[ ! -L $2 ]]; then
        printf "Symlinking: %s -> %s\n" "$1" "$2"
        if [[ ! -d "$(dirname "$2")" ]]; then
            mkdir -p "$(dirname "$2")"
        fi
        ln -s "$1" "$2"
    fi
    if [[ -f $2 ]] && [[ ! -L $2 ]]; then
        printf "File found: %s\n" "$2"
    fi
}

rm_on_update_if_needed() {
    # 
    # Arguments:
    #   $1 - str: path to local installed executable
    #   $2 - str: latest upstream release
    #   $3 - str: string representation of the current locally installed version
    #   $4 - array: list of files to remove
    echo "DEBUG OUTPUT: rm_on_update_if_needed"
    echo "$1"
    echo "$2"
    echo "$3"
    local uninstall_paths
    uninstall_paths=("$@")
    # drop the first three strings
    unset "uninstall_paths[0]"
    unset "uninstall_paths[1]"
    unset "uninstall_paths[2]"
    echo "${uninstall_paths[@]}"


    if [[ -f ${1} ]]; then
        if [[ ${2} != "${3}" ]]; then
            rm -f "${uninstall_paths[@]}"
        fi
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
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/89luca89/distrobox/tags' | jq -r '.[0].name')"
    currently_installed_version=$(distrobox version | awk -F: '/^distrobox/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}" "${install_path}-*")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    if [[ ! -f ${install_path} ]]; then
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
    fi
}

local_install_opa() {
    local install_path="${HOME}/.local/bin/opa"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/open-policy-agent/opa/tags' | jq -r '.[0].name')"
    currently_installed_version=$(opa version | awk -F: '/^Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "v${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    if [[ ! -f ${install_path} ]]; then
        if [[ ${_MACHINE_ARCH} == "x86_64" ]]; then
            curl -L -o "${install_path}" "https://openpolicyagent.org/downloads/${latest_release}/opa_linux_amd64_static"
        fi  
        if [[ ${_MACHINE_ARCH} == "aarch64" ]]; then
            curl -L -o "${install_path}" "https://openpolicyagent.org/downloads/${latest_release}/opa_linux_arm64_static"
        fi  
        chmod +x "${install_path}"
    fi
}

local_install_minikube() {
    local install_path="${HOME}/.local/bin/minikube"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes/minikube/tags' | jq -r '.[0].name')"
    currently_installed_version=$(minikube version | awk -F: '/^minikube version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    # minikube install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing minikube...\n"
        curl -LO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${_GOLANG_ARCH}"
        chmod +x "./minikube-linux-${_GOLANG_ARCH}"
        mv "./minikube-linux-${_GOLANG_ARCH}" "${install_path}"
    fi
}

local_install_kind() {
    local install_path="${HOME}/.local/bin/kind"
    local latest_release
    local currently_installed_version
    # kind tags alpha and stable, if it's alpha, use the latest stable - query with jq
    latest_release="$(curl -s 'https://api.github.com/repos/kubernetes-sigs/kind/tags' | jq -r '.[] | select(.name | contains("alpha") | not ).name' | head -1)"
    currently_installed_version=$(kind version | awk '/^kind/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    kind_numerical_version="${latest_release#v*}"

    # kind install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kind...\n"
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${latest_release}/kind-linux-${_GOLANG_ARCH}"
        chmod +x ./kind
        mv ./kind "${install_path}"
    fi
}

local_install_kubectl() {
    local install_path="${HOME}/.local/bin/kubectl"
    local latest_release
    local currently_installed_version

    latest_release=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    currently_installed_version=$(kubectl version 2>/dev/null | awk -F: '/^Client Version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    # kubectl install
    if [[ ! -f ${install_path} ]]; then
        printf "Installing kubectl...\n"
        curl -LO "https://dl.k8s.io/release/${latest_release}/bin/linux/${_GOLANG_ARCH}/kubectl"
        chmod +x ./kubectl
        mv ./kubectl "${install_path}"
    fi
}

local_install_terraform() {
    local install_path="${HOME}/.local/bin/terraform"
    local latest_release
    local currently_installed_version

    # terraform tags alpha, beta, and rc ... don't get those
    latest_release="$(
        curl -s 'https://api.github.com/repos/hashicorp/terraform/tags' \
            | jq -r '.[] | select(.name | contains("alpha") | not )| select(.name | contains("beta") | not ) | select(.name | contains("rc") | not).name' \
            | head -1 \
    )"
    currently_installed_version=$(terraform version | awk '/^Terraform/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')

    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    local terraform_version="${latest_release#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing terraform...\n"
        pushd /tmp/ || return
            rm -f terraform terraform.zip # just to make sure the zip command doesn't complain
            curl -Lo terraform.zip \
                "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${_GOLANG_ARCH}.zip"
            unzip terraform.zip
            cp terraform "${install_path}"
        popd || return
        chmod +x "${install_path}"
    fi
}

local_install_rustup() {
    local install_path="${HOME}/.cargo/bin/rustup"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/rust-lang/rustup/tags' | jq -r '.[0].name')"
    currently_installed_version=$(rustup --version 2>/dev/null| awk '/^rustup/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    if [[ ! -f ${install_path} ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    fi
}

local_install_gh() {
    local install_path="${HOME}/.local/bin/gh"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/cli/cli/tags' | jq -r '.[0].name')"
    currently_installed_version=$(gh version| awk '/^gh version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $3 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "v${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    local gh_numerical_version="${latest_release#v*}"
    if [[ ! -f ${install_path} ]]; then
        printf "Installing gh...\n"
        curl -Lo /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/${latest_release}/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}.tar.gz"
        tar -zxvf /tmp/gh.tar.gz -C /tmp/
        cp "/tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/bin/gh" "${install_path}"
        cp "/tmp/gh_${gh_numerical_version}_linux_${_GOLANG_ARCH}/share/man/man1/*" "${HOME}/.local/share/man/man1/"
    fi
}

local_install_neovim() {
    local install_path="${HOME}/.local/bin/nvim"
    local latest_release
    local currently_installed_version

    latest_release="$(curl -s 'https://api.github.com/repos/neovim/neovim/tags' | jq -r '.[0].name')"
    currently_installed_version=$(nvim --version| awk '/^NVIM/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    local neovim_numerical_version="${latest_release#v*}"

    if [[ ! -f ${install_path} ]]; then
        printf "Installing neovim from source ... \n"

        pushd /tmp/ || return
            wget -c "https://github.com/neovim/neovim/archive/refs/tags/${latest_release}.tar.gz"
            tar -zxvf "${latest_release}.tar.gz"
            pushd "neovim-${neovim_numerical_version}/" || return
                make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="${HOME}/.local/"
                make install
            popd || return
            rm -fr "neovim-${latest_release}/"
        popd || return
    fi
}

local_install_task() {
    local install_path="${HOME}/.local/bin/task"
    local completions_install_path="${HOME}/.local/share/bash-completion/completions/task"
    local latest_release
    currently_installed_version=$(task --version| awk '/^Task version/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $3 }')
    latest_release="$(curl -s 'https://api.github.com/repos/go-task/task/tags' | jq -r '.[0].name')"
    if [[ ${1} == "update" ]]; then
        local uninstall_paths=("${install_path}" "${completions_install_path}")
        rm_on_update_if_needed "${install_path}" "${latest_release}" "${currently_installed_version}" "${uninstall_paths[@]}"
    fi

    if [[ ! -f ${install_path} ]]; then
        printf "Installing task...\n"

        pushd /tmp/ || return
            wget -c "https://github.com/go-task/task/releases/download/${latest_release}/task_linux_${_GOLANG_ARCH}.tar.gz"
            tar -zxvf "task_linux_${_GOLANG_ARCH}.tar.gz"
            cp task "${install_path}"
            cp completion/bash/task.bash "${completions_install_path}"

            # cleanup the tarball artifacts
            for file in $(tar --list --file "task_linux_${_GOLANG_ARCH}.tar.gz"); do
                rm -f "${file}"
            done
            rm -fr completion
        popd || return
    fi
}


local_pipx_packages_install() {
    if which pipx > /dev/null 2>&1; then
        for pypkg in "${_PIPX_PACKAGE_LIST[@]}";
        do
            if [[ ! -d ${HOME}/.local/pipx/venvs/${pypkg} ]]; then
                pipx install "${pypkg}"
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
    local_install_task update
    pipx upgrade-all
}
