# Usa a imagem base do Ubuntu 24.04
FROM ubuntu:24.04

# Evita que a instalação de pacotes peça confirmações interativas
ENV DEBIAN_FRONTEND=noninteractive

# Instala as dependências mínimas para o script rodar e para criar um usuário
RUN apt-get update && apt-get install -y sudo git curl wget dialog apt-utils lsb-release

# Cria um usuário não-root para simular seu ambiente real
RUN useradd --create-home --shell /bin/bash victor && \
    usermod -aG sudo victor && \
    echo "victor ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Muda para o usuário não-root
USER victor

# Define o diretório de trabalho dentro do container
WORKDIR /home/victor/setup

# Copia todos os arquivos da pasta local (do seu PC) para o diretório de trabalho no container
COPY --chown=victor:victor . .

# Dá permissão de execução para o script
RUN chmod +x ./setup_ubuntu_cli.sh

# Comando que será executado ao iniciar o container
# Ele roda o script e depois fica "dormindo" para que possamos inspecionar o container
CMD ["/bin/bash", "-c", "./setup_ubuntu_cli.sh; sleep infinity"]
