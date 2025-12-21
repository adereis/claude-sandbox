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
    vim \
    python3 \
    python3-pip \
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
RUN chmod -R 777 /home/claude

WORKDIR /home/claude
CMD ["/bin/bash"]
