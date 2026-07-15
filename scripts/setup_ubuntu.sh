#!/bin/bash
# ==============================================================================
# Script de Setup de Ambiente de Desenvolvimento - Ubuntu 24.04 (Noble Numbat)
# Versão Final Consolidada
# ==============================================================================
set -e

# --- Variáveis de Configuração ---
export TZ=America/Sao_Paulo
UBUNTU_RELEASE_NAME=$(lsb_release -cs)

# --- Detecção de Distro ---
if grep -qi "pop" /etc/os-release; then
    DISTRO="popos"
elif grep -qi "ubuntu" /etc/os-release; then
    DISTRO="ubuntu"
else
    DISTRO="unknown"
fi
echo "🖥️  Distro detectada: ${DISTRO}"

# --- Pacotes Base (universais) ---
APT_PACKAGES=(
    # Essenciais, Build e Ferramentas de Sistema
    stow build-essential curl wget git gnupg software-properties-common apt-transport-https ca-certificates dbus-x11
    # Dependências de build para pyenv
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    # Shell, Terminal e Editores
    zsh vim neovim jq tree unzip
    # Ferramentas de Desenvolvimento
    python3-pip python3-venv python3-all-dev postgresql-client redis-tools pipx
    # Aplicações GUI
    qbittorrent
    # Suporte a AppImages
    libfuse2t64
    # Ferramentas CLI Modernas e Monitores
    bat eza fd-find ripgrep zoxide btop
)

# --- Pacotes condicionais por distro ---
if [[ "$DISTRO" == "ubuntu" ]]; then
    # GNOME-specific: extensões, tweaks, etc. (Pop!_OS 24.04+ usa COSMIC, não GNOME)
    APT_PACKAGES+=(gnome-boxes gnome-tweaks gnome-shell-extensions)
fi
PIPX_PACKAGES=(pipenv uv pre-commit)
PYTHON_VERSIONS_TO_INSTALL=(3.12.3 3.10.13)
PYTHON_GLOBAL_VERSION=3.12.3
FLATPAKS=(md.obsidian.Obsidian org.flameshot.Flameshot)
SNAP_PACKAGES=(spotify)
SNAP_CLASSIC_PACKAGES=(ghostty)

# --- Configuração Pessoal (PREENCHA ANTES DE RODAR!) ---
GIT_USER_NAME="Seu Nome"
GIT_USER_EMAIL="seu-email@exemplo.com"

# --- Funções de Limpeza e Instalação ---

preemptive_cleanup() {
    echo "🧹 Executando limpeza pesada de repositórios conflitantes..."
    sudo find /etc/apt/sources.list.d/ -type f \( -name "*microsoft*" -o -name "*vscode*" -o -name "*azure*" -o -name "*numix*" \) -delete
    sudo rm -f /etc/apt/sources.list.d/spotify.list
    sudo rm -f /etc/apt/keyrings/packages.microsoft.gpg /usr/share/keyrings/microsoft.gpg /etc/apt/keyrings/spotify.gpg
    echo "✅ Limpeza pesada concluída."
}

install_base_packages() {
    echo "📦 Instalando pacotes base do APT..."
    sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ | sudo tee /etc/timezone > /dev/null
    sudo apt-get clean
    echo "    - Verificando e corrigindo pacotes quebrados..."
    sudo apt-get --fix-broken install -y
    sudo apt-get update
    sudo apt-get install -y "${APT_PACKAGES[@]}"
}

install_nvm_and_nodejs() {
    echo "📦 Instalando NVM (Node Version Manager), Node.js (LTS) e Yarn..."
    curl -o- -L https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    echo "    - Instalando a versão LTS mais recente do Node.js..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
    echo "    - Instalando Yarn globalmente via npm..."
    npm install -g yarn
    echo "    - Versões instaladas:"; node -v; npm -v; yarn -v
}

install_pyenv_and_python_versions() {
    echo "🐍 Instalando pyenv e versões do Python..."
    if [ ! -d "$HOME/.pyenv" ]; then
        curl https://pyenv.run | bash
    fi
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    for version in "${PYTHON_VERSIONS_TO_INSTALL[@]}"; do
        if ! pyenv versions --bare | grep -q "^${version}$"; then
            echo "    - Instalando Python ${version}..."
            pyenv install "$version"
        else
            echo "    - Python ${version} já está instalado."
        fi
    done
    echo "    - Definindo Python global padrão como ${PYTHON_GLOBAL_VERSION}"
    pyenv global "$PYTHON_GLOBAL_VERSION"
}

install_aws_tools() {
    echo "📦 Instalando/Atualizando ferramentas da AWS (AWS CLI, SAM CLI)..."
    TEMP_AWS_DIR=$(mktemp -d); cd "$TEMP_AWS_DIR"
    echo "    - Baixando e instalando/atualizando AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install --update
    echo "    - Baixando e instalando/atualizando AWS SAM CLI..."
    wget -q "https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip" -O "sam.zip"
    unzip -q sam.zip -d sam-installation
    sudo ./sam-installation/install --update
    cd - > /dev/null; rm -rf "$TEMP_AWS_DIR"
}

add_custom_repos_and_install() {
    echo "📦 Adicionando repositórios de terceiros de forma silenciosa..."
    sudo install -m 0755 -d /etc/apt/keyrings

    # Google Chrome
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

    # Microsoft
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod ${UBUNTU_RELEASE_NAME} main" | sudo tee /etc/apt/sources.list.d/microsoft-prod.list

    # Brave Browser
    curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list

    # GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list

    # PGAdmin4
    curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/pgadmin4-archieve-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archieve-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" | sudo tee /etc/apt/sources.list.d/pgadmin4.list

    # Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

    # HashiCorp (Terraform)
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

    # Kubernetes (kubectl)
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    # Bruno (API Client)
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x9FA6017ECABE0266" | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/bruno.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/bruno.gpg] http://debian.usebruno.com/ bruno stable" | sudo tee /etc/apt/sources.list.d/bruno.list

    echo "🔄 Atualizando listas de pacotes..."
    sudo apt-get update

    echo "📦 Instalando pacotes de repositórios customizados..."
    CUSTOM_APT_PACKAGES=(
        google-chrome-stable brave-browser
        code powershell azure-cli gh dotnet-sdk-8.0 pgadmin4-desktop
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        terraform kubectl bruno
    )
    sudo apt-get install -y "${CUSTOM_APT_PACKAGES[@]}"
}


install_deb_packages() {
    echo "📦 Instalando pacotes .deb..."
    TEMP_DEB_DIR=$(mktemp -d); cd "$TEMP_DEB_DIR"

    echo "    - Baixando e instalando Discord..."; wget -qO discord.deb "https://discord.com/api/download?platform=linux&format=deb" && sudo dpkg -i discord.deb || true
    echo "    - Baixando e instalando TeamViewer..."; wget -qO teamviewer.deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" && sudo dpkg -i teamviewer.deb || true
    echo "    - Baixando e instalando AppImageLauncher..."; wget -qO appimagelauncher.deb "https://github.com/TheAssassin/AppImageLauncher/releases/download/v3.0.0-beta-3/appimagelauncher_3.0.0-beta-2-gha287.96cb937_amd64.deb" && sudo dpkg -i appimagelauncher.deb || true

    echo "    - Corrigindo TODAS as dependências quebradas de uma vez..."; sudo apt-get install -f -y
    cd - > /dev/null; rm -rf "$TEMP_DEB_DIR"
}

install_extra_binaries() {
    echo "📦 Instalando binários extras (k9s)..."
    TEMP_BIN_DIR=$(mktemp -d); cd "$TEMP_BIN_DIR"
    echo "    - Baixando e instalando k9s..."; wget -qO k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz"; tar -xzf k9s.tar.gz; sudo install k9s /usr/local/bin
    cd - > /dev/null; rm -rf "$TEMP_BIN_DIR"
}

install_flatpaks() {
    echo "💿 Instalando pacotes Flatpak..."
    sudo apt-get install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    for app in "${FLATPAKS[@]}"; do
        flatpak install -y flathub "$app"
    done
}

install_snap_packages() {
    echo "📦 Instalando pacotes via Snap..."
    for pkg in "${SNAP_PACKAGES[@]}"; do
        echo "    - Instalando Snap: ${pkg}"
        sudo snap install "$pkg"
    done
    for pkg in "${SNAP_CLASSIC_PACKAGES[@]}"; do
        echo "    - Instalando Snap (classic): ${pkg}"
        sudo snap install "$pkg" --classic
    done
}

install_nerd_fonts() {
    echo "🔤 Instalando Nerd Fonts (FiraCode)..."
    local fonts_dir="$HOME/.local/share/fonts"; if [ ! -d "$fonts_dir/FiraCode" ]; then mkdir -p "$fonts_dir"; cd "$fonts_dir"; wget -q -O FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip; unzip -q FiraCode.zip -d FiraCode; rm FiraCode.zip; fc-cache -f -v; cd - > /dev/null; echo "    - Fonte FiraCode Nerd Font instalada!"; else echo "    - Fonte FiraCode Nerd Font já parece estar instalada."; fi
}

install_pipx_packages() {
    echo "🐍 Instalando ferramentas Python CLI com pipx..."
    export PATH="$PATH:$HOME/.local/bin"
    for pkg in "${PIPX_PACKAGES[@]}"; do pipx install "$pkg"; done
}

# --- Configuração ---
stow_dotfiles() {
    echo "🔗 Gerenciando dotfiles com Stow..."
    local SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    local REPO_ROOT=$( dirname "$SCRIPT_DIR" )
    echo "    - Removendo arquivos de configuração padrão para evitar conflitos..."
    rm -f "$HOME/.zshrc"
    echo "    - Linkando zsh..."
    stow --dir=$REPO_ROOT --target=$HOME -R zsh
}
configure_system() {
    echo "⚙️  Configurando o sistema e atalhos..."

    # Docker
    sudo groupadd -f docker
    sudo usermod -aG docker "$(whoami)"

    # Git
    echo "    - Configurando Git..."
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global init.defaultBranch main

    # Terminal padrão (funciona em qualquer DE)
    echo "    - Definindo Ghostty como terminal padrão..."
    if command -v ghostty &> /dev/null; then
        sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$(which ghostty)" 50
        sudo update-alternatives --set x-terminal-emulator "$(which ghostty)"
    fi

    # Temas visuais e atalhos (apenas GNOME — Pop!_OS 24.04+ usa COSMIC)
    if [[ "$DISTRO" != "popos" ]]; then
        echo "    - Aplicando temas visuais (GNOME)..."
        gsettings set org.gnome.desktop.interface gtk-theme "Yaru-dark"
        gsettings set org.gnome.desktop.interface icon-theme "Yaru"
        gsettings set org.gnome.desktop.interface cursor-theme "Yaru"

        # Atalhos de teclado (GNOME)
        echo "    - Configurando atalhos de teclado..."
        echo "      - Desabilitando atalhos de screenshot padrão do GNOME..."
        gsettings set org.gnome.shell.keybindings screenshot '[]'
        gsettings set org.gnome.shell.keybindings show-screenshot-ui '[]'
        gsettings set org.gnome.shell.keybindings screenshot-window '[]'

        echo "      - Criando atalho customizado para o Flameshot..."
        local CUSTOM_KEYBINDING_PATH_FLAMESHOT="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_FLAMESHOT} name 'Flameshot'
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_FLAMESHOT} command 'flatpak run org.flameshot.Flameshot gui'
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_FLAMESHOT} binding 'Print'

        local CUSTOM_KEYBINDING_PATH_TERM="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_TERM} name 'Abrir Terminal'
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_TERM} command 'ghostty'
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDING_PATH_TERM} binding '<Super>t'

        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['${CUSTOM_KEYBINDING_PATH_FLAMESHOT}', '${CUSTOM_KEYBINDING_PATH_TERM}']"
    else
        echo "    - Pop!_OS com COSMIC detectado. Temas e atalhos GNOME ignorados."
        echo "    - Configure temas e atalhos via Configurações do COSMIC."
    fi
}
create_initial_config_dirs() {
    echo "🏗️  Criando diretórios de configuração iniciais..."

    # Cria a pasta .kube para evitar erros no Zsh
    echo "    - Criando ~/.kube..."
    mkdir -p ~/.kube
}

configure_zsh() {
    echo "👽 Configurando a base do Zsh e Oh My Zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    if [[ "$SHELL" != */zsh ]]; then
        echo "    - Definindo Zsh como shell padrão..."
        sudo chsh -s "$(which zsh)" "$(whoami)"
    fi
}

install_zsh_plugins_and_themes() {
    echo "👽 Instalando plugins e temas do Oh My Zsh..."
    OMZ_CUSTOM_PLUGINS="$HOME/.oh-my-zsh/custom/plugins"
    OMZ_CUSTOM_THEMES="$HOME/.oh-my-zsh/custom/themes"
    mkdir -p "$OMZ_CUSTOM_PLUGINS"
    mkdir -p "$OMZ_CUSTOM_THEMES"

    echo "    - Instalando/Verificando plugins..."
    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$OMZ_CUSTOM_PLUGINS/zsh-autosuggestions"
    fi
    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$OMZ_CUSTOM_PLUGINS/zsh-syntax-highlighting"
    fi
    if [ ! -d "$OMZ_CUSTOM_PLUGINS/zsh-completions" ]; then
        git clone https://github.com/zsh-users/zsh-completions "$OMZ_CUSTOM_PLUGINS/zsh-completions"
    fi

    echo "    - Instalando/Verificando temas..."
    if [ ! -d "$OMZ_CUSTOM_THEMES/spaceship-prompt" ]; then
        git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$OMZ_CUSTOM_THEMES/spaceship-prompt" --depth=1
    fi
    if [ ! -d "$OMZ_CUSTOM_THEMES/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$OMZ_CUSTOM_THEMES/powerlevel10k"
    fi
}

cleanup() {
    echo "🧹 Limpando o sistema...";
    sudo apt-get autoremove -y;
    sudo apt-get clean
}

# --- Execução Principal ---
main() {
    echo "🚀 Iniciando setup do ambiente de desenvolvimento (Edição Final)..."
    preemptive_cleanup
    install_base_packages
    install_pyenv_and_python_versions
    install_nvm_and_nodejs
    install_aws_tools
    add_custom_repos_and_install
    install_deb_packages
    install_extra_binaries
    install_flatpaks
    install_snap_packages
    install_nerd_fonts
    install_pipx_packages

    create_initial_config_dirs
    configure_system
    configure_zsh
    install_zsh_plugins_and_themes

    stow_dotfiles

    cleanup

    echo "✅ Setup concluído com sucesso! (Distro: ${DISTRO})"
    echo "---"
    echo "⚠️  CHECKLIST DE AÇÕES PÓS-INSTALAÇÃO ⚠️"
    echo ""
    echo "   1. REINICIE A SESSÃO: Faça logout/login para aplicar todas as mudanças."
    echo ""
    if [[ "$DISTRO" == "ubuntu" ]]; then
        echo "   2. ESCOLHA A SESSÃO XORG (Para o Flameshot funcionar): Na tela de login, clique na engrenagem e escolha 'Ubuntu on Xorg'."
        echo ""
    fi
    echo "   3. CONFIGURE O TERMINAL: Abra o Ghostty. Crie ~/.config/ghostty/config se quiser customizar (fonte, tema, etc.)."
    echo ""
    echo "   4. CONFIGURE O ZSH: Abra seu ~/.zshrc e verifique/adicione as linhas para pyenv, zoxide e plugins."
    echo ""
    echo "   5. TESTE O DOCKER: Abra um novo terminal e rode 'docker run hello-world'."
    echo ""
    if [[ "$DISTRO" == "ubuntu" ]]; then
        echo "   6. INSTALE EXTENSÕES DO GNOME: Consulte gnome_extensions.txt (seções 'Universal' + 'Ubuntu only')."
        echo "      → Instale via https://extensions.gnome.org/"
    elif [[ "$DISTRO" == "popos" ]]; then
        echo "   6. COSMIC: Extensões GNOME não se aplicam. Configure temas/atalhos via Configurações do COSMIC."
    fi
    echo ""
    echo "   7. LOGINS E SINCRONIZAÇÃO: Faça login nos seus apps e autentique suas CLIs (gh, az, aws)."
    echo "---"
    echo "💡 LEMBRETE DE FLUXO DE TRABALHO PYTHON COM PYENV 💡"
    echo ""
    echo "   # Para projetos novos (usando o Python global padrão, ex: 3.12.3):"
    echo "   cd meu-projeto-novo/"
    echo "   pipenv install # ou uv venv"
    echo ""
    echo "   # Para projetos legados (exigindo uma versão específica, ex: 3.10.13):"
    echo "   cd meu-projeto-legado/"
    echo "   pyenv local 3.10.13  # Isso cria o arquivo .python-version"
    echo "   pipenv install # ou uv venv (agora usará o Python 3.10)"
    echo "---"
    echo "💡 DICA NEOVIM: Para começar a configurar seu NeoVim, crie o arquivo ~/.config/nvim/init.lua"
}

main