FROM ubuntu:18.04 as base

ARG SYS161="sys161-2.0.3"
ARG BINUTILS161="binutils-2.24+os161-2.1"
ARG GCC161="gcc-4.8.3+os161-2.1"
ARG GDB161="gdb-7.8+os161-2.1"
ARG MIRROR="http://www.ece.ubc.ca/~os161/download"
ARG SOURCE_PREFIX="/usr/local/src"
ARG TMP_DIR="/tmp/os161"
ARG INSTALL_PREFIX="/usr/local/os161"

ENV SYS161=$SYS161
ENV BINUTILS161=$BINUTILS161
ENV GCC161=$GCC161
ENV GDB161=$GDB161
ENV MIRROR=$MIRROR
ENV SOURCE_PREFIX=$SOURCE_PREFIX
ENV TMP_DIR=$TMP_DIR
ENV INSTALL_PREFIX=$INSTALL_PREFIX

LABEL maintainer="John Ramsden"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN echo "deb http://us.archive.ubuntu.com/ubuntu/ bionic universe" >> /etc/apt/sources.list
RUN apt-get --yes update && \
    apt-get install --yes --no-install-recommends \
        bmake ncurses-dev libmpc-dev wget curl build-essential tmux ca-certificates && \
    rm -rf /var/lib/apt/lists/*

FROM base AS builder

RUN mkdir -p "${SOURCE_PREFIX}" "${TMP_DIR}" && cd "${SOURCE_PREFIX}" && \
    curl "${MIRROR}/${BINUTILS161}.tar.gz" | tar -xz && \
    curl "${MIRROR}/${GCC161}.tar.gz" | tar -xz && \
    curl "${MIRROR}/${GDB161}.tar.gz" | tar -xz && \
    curl "${MIRROR}/${SYS161}.tar.gz" | tar -xz

COPY "build.sh" "patches" "${TMP_DIR}/"
RUN /tmp/os161/build.sh -d \
    -s "${SYS161}" \
    -b "${BINUTILS161}" \
    -g "${GCC161}" \
    -e "${GDB161}" \
    -m "${MIRROR}" \
    -p "${SOURCE_PREFIX}"

FROM base AS runner

COPY --from=builder "${INSTALL_PREFIX}" "${INSTALL_PREFIX}"

RUN cd "${INSTALL_PREFIX}/os161/bin" && \
    for file in *; do ln -s --relative "${file}" "/usr/local/bin/${file:13}" && ln -s --relative "${file}" "/usr/local/bin/${file}"; done && \
    cd "${INSTALL_PREFIX}/sys161/bin" && \
    for file in *; do ln -s --relative "${file}" "/usr/local/bin/${file}"; done && \
    useradd --create-home --shell=/bin/bash --user-group os161 && \
    echo 'set auto-load safe-path /' > /home/os161/.gdbinit

USER os161
WORKDIR /home/os161
CMD ["/bin/bash"]
