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
    zsh \
    fish \
    && rm -rf /var/lib/apt/lists/*

# Set up zsh configuration
RUN cp /etc/zsh/newuser.zshrc.recommended /root/.zshrc
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

WORKDIR /workspace

