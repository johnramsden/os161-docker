#!/bin/bash

set -e

declare -a build_deps=('bmake' 'ncurses-dev' 'libmpc-dev' 'wget' 'curl' 'build-essential' 'ca-certificates')

SYS161="sys161-2.0.3"
BINUTILS161="binutils-2.24+os161-2.1"
GCC161="gcc-4.8.3+os161-2.1"
GDB161="gdb-7.8+os161-2.1"
MIRROR="http://www.ece.ubc.ca/~os161/download"

PATCH_DIR="/tmp/os161"
SOURCE_PREFIX="/usr/local/src/os161"
INSTALL_PREFIX="/usr/local/os161"

ubuntu_ver="bionic"

reqs=false
fetch_deps=true

export CC="gcc"
export CFLAGS=

install_requirements() {
    echo "deb http://us.archive.ubuntu.com/ubuntu/ ${ubuntu_ver} universe" >> /etc/apt/sources.list
    apt update --yes
    apt install --yes --no-install-recommends "${build_deps[@]}"
}

get_deps() {
    declare -a archives=(
        "${MIRROR}/${BINUTILS161}.tar.gz"
        "${MIRROR}/${GCC161}.tar.gz"
        "${MIRROR}/${GDB161}.tar.gz"
        "${MIRROR}/${SYS161}.tar.gz"
    )
    declare -a patches=(
        "https://gitlab.labs.nic.cz/turris/openwrt/raw/9e44516bc5fc71184b63a71a929fa18be7b0bfdc/toolchain/gdb/patches/110-no_extern_inline.patch"
    )

    (
        set -e
        cd "${SOURCE_PREFIX}"
        for fd in "${archives[@]}"; do wget --progress=bar:force "${fd}"; done
        for file in *.tar.gz; do tar -xzf "${file}" && rm -f "${file}"; done
    )
    (
        set -e
        mkdir -p "${PATCH_DIR}"
        cd "${PATCH_DIR}"
        for fd in "${patches[@]}"; do wget --progress=bar:force "${fd}"; done
    )
}

build_binutils() {
    echo '*** Building binutils ***'
    if ! (
        set -e
        cd "${SOURCE_PREFIX}/${BINUTILS161}"
        touch ./*.info intl/plural.c
        ./configure \
            --nfp \
            --disable-werror \
            --target=mips-harvard-os161 \
            --prefix="${INSTALL_PREFIX}/os161" 2>&1
        make -j"$(nproc)" 2>&1
        make install 2>&1
        rm -rf "${SOURCE_PREFIX:?}/${BINUTILS161}"
    ) > /var/log/binutils.log; then
        tail /var/log/binutils.log
        exit 1
    fi
}

build_gcc() {
    echo '*** Building gcc ***'
    if ! (
        set -e
        touch "${SOURCE_PREFIX}/${GCC161}"/*.info "${SOURCE_PREFIX}/${GCC161}/intl/plural.c"
        mkdir -p /tmp/gcc-build
        cd /tmp/gcc-build
        "${SOURCE_PREFIX}/${GCC161}/configure" \
            --enable-languages=c,lto \
            -nfp --disable-shared \
            --disable-threads \
            --disable-libmudflap \
            --disable-libssp \
            --disable-libstdcxx \
            --disable-nls \
            --target=mips-harvard-os161 \
            --prefix="${INSTALL_PREFIX}/os161" 2>&1
        make -j"$(nproc)" 2>&1
        make install 2>&1
        cd ~ && rm -rf /tmp/gcc-build
    ) > /var/log/gcc.log; then
        tail /var/log/gcc.log && exit 1
    fi
}


build_gdb() {
    echo '*** Building gdb ***'
    if ! (
        set -e
        cd "${SOURCE_PREFIX}/${GDB161}"
        patch --strip=1 < "${PATCH_DIR}/110-no_extern_inline.patch"
        touch ./*.info intl/plural.c
        ./configure \
            --disable-werror \
            --target=mips-harvard-os161 \
            --prefix="${INSTALL_PREFIX}/os161" 2>&1
        make -j"$(nproc)" 2>&1
        make install 2>&1
        rm -rf "${SOURCE_PREFIX:?}/${GDB161}"
    ) > /var/log/gdb.log; then
        tail /var/log/gdb.log && exit 1
    fi
}

build_world() {
    echo '*** Building System/161 ***'
    if ! (
        set -e
        cd "${SOURCE_PREFIX}/${SYS161}"
        ./configure \
            --prefix="${INSTALL_PREFIX}/sys161" mipseb
        make -j"$(nproc)" 2>&1
        make install 2>&1
        mv "${SOURCE_PREFIX:?}/${SYS161}" "${SOURCE_PREFIX:?}/os161"
    ) > /var/log/sys161.log; then
        tail /var/log/sys161.log && exit 1
    fi
}

link_files() {
    (
        set -e
        cd "${INSTALL_PREFIX}/os161/bin"
        for file in *; do ln -s --relative "${file}" "/usr/local/bin/${file:13}"; done
    )
    (
        set -e
        cd "${INSTALL_PREFIX}/sys161/bin"
        for file in *; do ln -s --relative "${file}" "/usr/local/bin/${file}"; done
    )
}

help() {
    printf "%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t" "USAGE: $0" \
        "[-s SYS161_VERSION ]" \
        "[-b BINUTILS161_VERSION ]" \
        "[-g GCC161_VERSION ]" \
        "[-e GDB161_VERSION ]" \
        "[-m MIRROR_VERSION ]" \
        "[-p SOURCE_PREFIX ]" \
        "[-r ] Install requirements" \
        "[-d ] Use pre-downloaded source archives in SOURCE_PREFIX"
}

main() {
    mkdir -p "${SOURCE_PREFIX}"/{os161,sys161}

    "${reqs}" && install_requirements
    "${fetch_deps}" && get_deps

    build_binutils
    build_gcc
    build_gdb
    build_world
    link_files
}

options=':s:b:g:e:m:p:r:dh'
while getopts $options option
do
    case $option in
        s  ) SYS161=${OPTARG};;
        b  ) BINUTILS161=${OPTARG};;
        g  ) GCC161=${OPTARG};;
        e  ) GDB161=${OPTARG};;
        m  ) MIRROR=${OPTARG};;
        p  ) SOURCE_PREFIX=${OPTARG};;
        r  ) reqs=true;;
        d  ) fetch_deps=false;;
        h  ) help;;
        \? ) echo "Unknown option: -${OPTARG}" >&2; exit 1;;
        :  ) echo "Missing option argument for -${OPTARG}" >&2; exit 1;;
        *  ) echo "Unimplemented option: -${OPTARG}" >&2; exit 1;;
    esac
done

shift $((OPTIND - 1))

echo "SYS161=${SYS161}"
echo "BINUTILS161=${BINUTILS161}"
echo "GCC161=${GCC161}"
echo "GDB161=${GDB161}"
echo "MIRROR=${MIRROR}"
echo "SOURCE_PREFIX=${SOURCE_PREFIX}"
echo "INSTALL_PREFIX=${INSTALL_PREFIX}"

main
