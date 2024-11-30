# Use Ubuntu base image
FROM ubuntu:latest

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    curl \
    git \
    sudo \
    systemd \
    systemd-sysv \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Create test user
RUN useradd -m tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester

# Set up autologin for tester user
RUN mkdir -p /etc/systemd/system/console-getty.service.d/
COPY override.conf /etc/systemd/system/console-getty.service.d/

# Set up zsh configuration
RUN cp /etc/zsh/newuser.zshrc.recommended /home/tester/.zshrc && \
    chown -R tester:tester /home/tester/.zshrc
USER tester
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
USER root

# Set zsh as default shell for tester
RUN chsh -s /usr/bin/zsh tester

WORKDIR /workspace

# Use systemd as entrypoint
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT [ "/sbin/init" ]
