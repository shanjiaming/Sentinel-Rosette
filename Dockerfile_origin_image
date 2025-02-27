# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set non-interactive mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install required packages (we no longer install libfontconfig1)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    sudo \
    build-essential \
    python3 \
    python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Install the Foundry toolchain (forge, cast, anvil)
RUN bash -c "curl -L https://foundry.paradigm.xyz | bash && \
    export PATH=\"/root/.foundry/bin:\$PATH\" && \
    foundryup"

# Switch to /tmp directory for Racket installation
WORKDIR /tmp

# Download and install Racket
RUN wget https://download.racket-lang.org/installers/8.15/racket-8.15-x86_64-linux-cs.sh && \
    chmod +x racket-8.15-x86_64-linux-cs.sh && \
    # Installer prompts:
    # 1. Unix-style distribution? -> no
    # 2. Installation location: option 2 (/usr/local/racket)
    # 3. System links directory: /usr/local
    printf "no\n2\n/usr/local\n" | sh racket-8.15-x86_64-linux-cs.sh && \
    rm racket-8.15-x86_64-linux-cs.sh

# Add Racket's bin directory to PATH
ENV PATH="/usr/local/racket/bin:${PATH}"

# Set environment variable to skip docs (may not be sufficient by itself)
ENV PLTC_NO_DOCS=true

# Install Racket packages: rosette and debug with the --no-doc flag to skip documentation build
RUN raco pkg install --auto --no-docs rosette && \
    raco pkg install --auto --no-docs debug

RUN ln -s $(which python3) /usr/local/bin/python

# Set the default working directory and start bash
WORKDIR /root
CMD ["bash"]
