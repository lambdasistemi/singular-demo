FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv nodejs npm jq curl ca-certificates tmux \
    && rm -rf /var/lib/apt/lists/*
