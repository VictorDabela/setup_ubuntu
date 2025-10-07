# 🚀 Ambiente de Desenvolvimento Automatizado para Ubuntu

Este repositório contém um conjunto de scripts e arquivos de configuração ("dotfiles") para automatizar a instalação e configuração de um ambiente de desenvolvimento completo em uma nova instalação do Ubuntu (focado na versão 24.04 "Noble Numbat").

O objetivo é transformar o processo de "configurar um novo notebook", que levaria horas ou dias, em uma tarefa de poucos minutos.

## 📜 Conteúdo

O script principal instala e configura uma vasta gama de ferramentas, incluindo:

* **Ambiente de Shell:**
    * Zsh + Oh My Zsh
    * Temas (Spaceship, Powerlevel10k) e Plugins (Autosuggestions, Syntax Highlighting)
    * Terminal Hyper

* **Ambiente de Desenvolvimento:**
    * `pyenv` para gerenciar múltiplas versões do Python (3.12 e 3.10)
    * `nvm` para gerenciar múltiplas versões do Node.js (instalando a LTS mais recente)
    * Ferramentas Python via `pipx` (`pipenv`, `uv`, `docker-compose`, `pre-commit`)
    * Ferramentas do ecossistema .NET (SDK 8.0) e PowerShell

* **Ferramentas Cloud & DevOps:**
    * Docker & Docker Compose
    * AWS CLI & AWS SAM CLI
    * Terraform
    * Kubernetes (kubectl) e k9s

* **Ferramentas de CLI (Qualidade de Vida):**
    * `bat` (um `cat` com superpoderes)
    * `eza` (um `ls` moderno)
    * `fd-find` (um `find` simplificado)
    * `ripgrep` (um `grep` turbinado)
    * `zoxide` (um `cd` inteligente)
    * `btop` (um monitor de sistema moderno)

* **Aplicativos Gráficos (GUI):**
    * Navegadores (Google Chrome, Brave)
    * Editores e Clientes de API (VS Code, Insomnia)
    * Comunicação (Discord, Slack, Teams)
    * Outros (Spotify, pgAdmin4, Flameshot, etc.)

## ⚙️ Pré-Requisitos: Preparando os Arquivos de Configuração

Antes de executar os scripts, você precisa coletar 3 arquivos de configuração da sua máquina antiga e colocá-los na raiz deste repositório.

1.  **.zshrc:** Sua configuração do Zsh (aliases, plugins, etc.).
    * **Como obter:** `cp ~/.zshrc .`
2.  **.hyper.js:** Sua configuração do terminal Hyper (tema, fonte, plugins).
    * **Como obter:** `cp ~/.hyper.js .`
3.  **insomnia_config.tar.gz:** Seu backup de dados do Insomnia.
    * **Como criar:** `tar -czvf insomnia_config.tar.gz -C ~/.config Insomnia`

A estrutura da pasta, antes de rodar o setup, deve ser:
```
.
├── .hyper.js
├── .zshrc
├── insomnia_config.tar.gz
└── scripts/
    ├── setup_ubuntu.sh
    └── setup_ubuntu_cli.sh
```

## ⚡ Como Usar

### 1. Clonar o Repositório
Na sua máquina nova e limpa, clone este repositório:
```bash
git clone <URL_DO_SEU_REPOSITORIO> ~/dotfiles
cd ~/dotfiles
```

### 2. Preparar os Arquivos
Mova os arquivos de pré-requisito (`.zshrc`, etc.) para a raiz da pasta `~/dotfiles`, como descrito acima.

### 3. Escolher e Executar o Script
Existem duas versões do script na pasta `scripts/`. Dê permissão de execução a elas: `chmod +x scripts/*.sh`.

#### Opção A: Setup Completo (GUI)
Este é o script principal, para ser usado na sua máquina de trabalho. Ele instala **tudo**: ferramentas de linha de comando e todos os aplicativos gráficos.

```bash
./scripts/setup_ubuntu.sh
```

#### Opção B: Setup Apenas CLI (Para Servidores ou Teste)
Esta versão instala **apenas** as ferramentas de linha de comando. É perfeita para testar em um container Docker ou para configurar um servidor de desenvolvimento remoto.

```bash
./scripts/setup_ubuntu_cli.sh
```

## 🐳 Teste com Docker
É altamente recomendado testar o script `setup_ubuntu_cli.sh` em um ambiente Docker para validar as instalações de CLI.

1.  **Crie um `Dockerfile`** na raiz do projeto:
    ```dockerfile
    # Usa a imagem base do Ubuntu 24.04
    FROM ubuntu:24.04

    # Evita que a instalação de pacotes peça confirmações interativas
    ENV DEBIAN_FRONTEND=noninteractive

    # Instala as dependências mínimas para o script rodar
    RUN apt-get update && apt-get install -y sudo git curl wget dialog apt-utils lsb-release

    # Cria um usuário não-root para simular o ambiente real
    RUN useradd --create-home --shell /bin/bash victor && \
        usermod -aG sudo victor && \
        echo "victor ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

    USER victor
    WORKDIR /home/victor/setup

    # Copia o script e os arquivos de configuração
    COPY --chown=victor:victor . .

    # Dá permissão de execução
    RUN chmod +x ./scripts/setup_ubuntu_cli.sh

    # Roda o script e mantém o container ativo para inspeção
    CMD ["/bin/bash", "-c", "./scripts/setup_ubuntu_cli.sh; sleep infinity"]
    ```

2.  **Construa e execute:**
    ```bash
    # Construir a imagem (vai demorar)
    docker build --no-cache -t teste-ambiente .

    # Rodar o container em segundo plano
    docker run -d --name teste-container --rm teste-ambiente

    # Acompanhar os logs
    docker logs -f teste-container
    ```

## ✅ Checklist Pós-Instalação

Após a execução do script na sua máquina nova, siga estes passos manuais:

1.  **Reinicie a Sessão:** Faça logout/login para que todas as mudanças (especialmente o shell Zsh) tenham efeito.

2.  **Configure o Terminal:** Abra o Hyper, vá nas configurações (`Ctrl + ,`) e mude a fonte para `FiraCode Nerd Font Mono` para ter todos os ícones visuais.

3.  **Configure o Zsh:** Abra seu `~/.zshrc` e garanta que as seguintes linhas estão presentes para ativar os plugins e ferramentas:
    ```zsh
    # No final do arquivo, para pyenv:
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # Na lista de plugins, para auto-sugestões e syntax highlighting:
    plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

    # No final do arquivo, para o zoxide:
    eval "$(zoxide init zsh)"
    ```

4.  **Instale Extensões do GNOME:** Visite [extensions.gnome.org](https://extensions.gnome.org/) e instale a extensão **Forge** para recriar a experiência de tiling de janelas do Pop!\_OS.

5.  **Logins e Sincronização:** Faça login no Chrome/Brave, VS Code (para o Settings Sync), Slack, etc., e autentique suas CLIs (`aws configure`, `gh auth login`, `az login`).
