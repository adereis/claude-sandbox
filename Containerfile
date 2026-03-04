FROM registry.fedoraproject.org/fedora:42

# Install Node.js and essential dev tools
RUN dnf install -y \
    nodejs \
    npm \
    git \
    git-extras \
    git-filter-repo \
    gh \
    ripgrep \
    fd-find \
    jq \
    tree \
    vim \
    python3 \
    python3-pip \
    tinyproxy \
    && dnf clean all

# Passwordless sudo for development convenience
RUN dnf install -y sudo && \
    echo "ALL ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nopasswd && \
    dnf clean all

# C/C++ development environment
RUN dnf install -y \
    # Compilers
    gcc \
    gcc-c++ \
    clang \
    # Build systems
    cmake \
    make \
    ninja-build \
    autoconf \
    automake \
    libtool \
    pkgconf \
    meson \
    # Debugging & profiling
    gdb \
    valgrind \
    strace \
    ltrace \
    perf \
    # Networking tools
    iproute \
    # Static analysis & formatting
    clang-tools-extra \
    cppcheck \
    bear \
    # Sanitizer libraries
    libasan \
    libubsan \
    libtsan \
    liblsan \
    # Common development libraries
    glibc-devel \
    libpcap-devel \
    libcmocka-devel \
    openssl-devel \
    zlib-devel \
    # Documentation
    man-db \
    man-pages \
    doxygen \
    && dnf clean all

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create home directory structure (world-accessible for --userns=keep-id)
RUN mkdir -p /home/claude/projects
COPY bashrc /home/claude/.bashrc

# Network filtering proxy configuration
COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY network-whitelist.conf /etc/tinyproxy/network-whitelist.conf
COPY network-whitelist-gcp.conf /etc/tinyproxy/network-whitelist-gcp.conf
COPY network-whitelist-aws.conf /etc/tinyproxy/network-whitelist-aws.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod -R 777 /home/claude && \
    chmod 755 /usr/local/bin/entrypoint.sh

WORKDIR /home/claude
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
