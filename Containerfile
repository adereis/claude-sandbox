FROM registry.fedoraproject.org/fedora:42

# Install Node.js and essential dev tools
RUN dnf install -y \
    nodejs \
    npm \
    git \
    ripgrep \
    fd-find \
    vim \
    && dnf clean all

# Python and image processing libraries
RUN dnf install -y \
    python3 python3-pip python3-devel \
    libjpeg-turbo-devel zlib-devel libwebp-devel \
    libtiff-devel freetype-devel lcms2-devel \
    jpegoptim ImageMagick \
    && dnf clean all

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create home directory structure (world-accessible for --userns=keep-id)
RUN mkdir -p /home/claude/projects
COPY bashrc /home/claude/.bashrc
RUN chmod -R 777 /home/claude

WORKDIR /home/claude
CMD ["/bin/bash"]
