#!/bin/bash

set -e

declare -a build_deps=('bmake' 'ncurses-dev' 'libmpc-dev' 'wget' 'build-essential')

SYS161="sys161-2.0.3"
BINUTILS161="binutils-2.24+os161-2.1"
GCC161="gcc-4.8.3+os161-2.1"
GDB161="gdb-7.8+os161-2.1"
MIRROR="http://www.ece.ubc.ca/~os161/download"

SOURCE_PREFIX="/usr/local/src"

ubuntu_ver="bionic"

reqs=false
fetch_deps=true

export CC="gcc"
export CFLAGS=

PATH="${SOURCE_PREFIX}/sys161/bin:${SOURCE_PREFIX}/os161/bin:${PATH}"
export PATH

install_requirements() {
    echo "deb http://us.archive.ubuntu.com/ubuntu/ ${ubuntu_ver} universe" >> /etc/apt/sources.list
    apt update --yes
    apt install --yes --no-install-recommends "${build_deps[@]}"
}

get_deps() {
    declare -a file_links=(
        "${MIRROR}/${BINUTILS161}.tar.gz"
        "${MIRROR}/${GCC161}.tar.gz"
        "${MIRROR}/${GDB161}.tar.gz"
        "${MIRROR}/${SYS161}.tar.gz"
    )
    (
        cd "${SOURCE_PREFIX}"
        for fd in "${file_links[@]}"; do wget --progress=bar:force "${fd}"; done
        for file in *.tar.gz; do tar -xzf "${file}" && rm -f "${file}"; done
    )
}

build_binutils() {
    echo '*** Building binutils ***'
    (
        cd "${SOURCE_PREFIX}/${BINUTILS161}"
        touch ./*.info intl/plural.c
        ./configure \
            --nfp \
            --disable-werror \
            --target=mips-harvard-os161 \
            --prefix="${SOURCE_PREFIX}/os161"
        make -j"$(nproc)" 2>&1
        make install 2>&1
        rm -rf "${SOURCE_PREFIX:?}/${BINUTILS161}"
    ) > /var/log/binutils.log || tail /var/log/binutils.log
}

build_gcc() {
    echo '*** Building gcc ***'
   (
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
            --target=mips-harvard-os161 --prefix="${SOURCE_PREFIX}/os161"
        make -j"$(nproc)" 2>&1
        make install 2>&1
        cd ~ && rm -rf /tmp/gcc-build
   ) > /var/log/gcc.log || tail /var/log/gcc.log
}


build_gdb() {
    echo '*** Building gdb ***'
    (
        cd "${SOURCE_PREFIX}/${GDB161}"
        touch ./*.info intl/plural.c
        ./configure \
            --disable-werror \
            --target=mips-harvard-os161 \
            --prefix="${SOURCE_PREFIX}/os161"
        make -j"$(nproc)" 2>&1
        make install 2>&1
        rm -rf "${SOURCE_PREFIX:?}/${GDB161}"
    ) > /var/log/gdb.log || tail /var/log/gdb.log
}

build_world() {
    echo '*** Building System/161 ***'
    (
        cd "${SOURCE_PREFIX}/${SYS161}"
        ./configure \
            --prefix="${SOURCE_PREFIX}/sys161" mipseb
        make -j"$(nproc)" 2>&1
        make install 2>&1
        mv "${SOURCE_PREFIX:?}/${SYS161}" "${SOURCE_PREFIX:?}/os161"
    ) > /var/log/sys161.log || tail /var/log/sys161.log
}

link_files() {
    (
        cd "${SOURCE_PREFIX}/os161/bin"
        for file in *; do ln -s --relative "${file}" "/usr/local/bin/${file:13}"; done
    )
    (
        cd "${SOURCE_PREFIX}/sys161/bin"
        for file in *; do ln -s --relative "${file}" "/usr/local/bin/${file}"; done
    )
}

create_user() {
    useradd --create-home --shell=/bin/bash --user-group os161
}

help() {
    printf "%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t%s\n\t" "USAGE: $0" \
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
    create_user
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

main
