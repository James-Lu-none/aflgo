FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV AFLGO=/aflgo

# Install required build tools, prebuilt LLVM 11 toolchain, Gold linker, Boost, and Python
RUN apt-get update -qq && \
    apt-get install -y -qq \
        build-essential \
        make \
        cmake \
        ninja-build \
        git \
        binutils-gold \
        binutils-dev \
        curl \
        wget \
        python3 \
        python3-dev \
        python3-pip \
        pkg-config \
        autoconf \
        automake \
        libtool \
        gawk \
        libboost-all-dev \
        clang-11 \
        llvm-11 \
        llvm-11-dev \
        llvm-11-tools \
        bison \
        flex \
        texinfo \
        tmux && \
    rm -rf /var/lib/apt/lists/*

# Install python dependencies for callgraph and distance generation
RUN pip3 install --no-cache-dir networkx pydot

# Configure LLVM 11 alternatives
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-11 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-11 100 && \
    update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-11 100 && \
    update-alternatives --install /usr/bin/opt opt /usr/bin/opt-11 100 && \
    update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-11 100

# Set up Gold plugin for LLVM LTO
RUN mkdir -p /usr/lib/bfd-plugins && \
    cp /usr/lib/llvm-11/lib/libLTO.so /usr/lib/bfd-plugins/ && \
    cp /usr/lib/llvm-11/lib/LLVMgold.so /usr/lib/bfd-plugins/

# Copy AFLGo source tree from current directory
WORKDIR /aflgo
COPY . /aflgo

# Build AFL fuzzer suite
RUN cd /aflgo/afl-2.57b && \
    make clean || true && \
    make -j$(nproc) && \
    make install

# Build AFLGo instrumentation pass
RUN cd /aflgo/instrument && \
    make clean || true && \
    LLVM_CONFIG=llvm-config CC=clang CXX=clang++ make -j$(nproc)

# Build distance calculator binary
RUN cd /aflgo/distance/distance_calculator && \
    rm -rf build && mkdir -p build && cd build && \
    cmake .. && make -j$(nproc) && \
    cp distance.bin /aflgo/distance/distance_calculator/

# Setup helper scripts if present
RUN mkdir -p /workspace && \
    if [ -d /aflgo/scripts ]; then \
        chmod +x /aflgo/scripts/* && \
        cp /aflgo/scripts/run_aflgo.sh /workspace/run_aflgo.sh 2>/dev/null || true; \
    fi

ENV PATH=/aflgo/scripts:/aflgo/instrument:/aflgo/afl-2.57b:/aflgo/distance:$PATH

WORKDIR /workspace
