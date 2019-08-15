#!/bin/sh

set -xe

ASCIIDOC_VERSION=8.6.9
CURL_VERSION=7.65.3
EXPAT_VERSION=2.2.7   # Note: download URL is unpredictable
GIT_VERSION=2.22.1
MUSL_VERSION=1.1.23
OPENSSL_VERSION=1.1.1c
ZLIB_VERSION=1.2.11
XMLTO_VERSION=0.0.28

DESTDIR=
PREFIX="$PWD/git"
WORK="$PWD/work"
NJOBS=$(nproc)

usage() {
    cat <<EOF
usage: $0 [-Cch] [-d destdir] [-j njobs] [-p prefix]
  -C         clean all build files including downloads
  -c         clean build files, preserving downloads
  -d DIR     staging directory for packaging (i.e. DESTDIR)
  -h         print this help message
  -j N       number of parallel jobs to use (default: max)
  -p DIR     installation prefix [\$PWD/git]
EOF
}

clean() {
    rm -rf "$WORK"
}

distclean() {
    clean
    rm -rf download
}

download() {
    mkdir -p download
    (
        cd download/
        xargs -n1 curl -LO <<EOF
https://curl.haxx.se/download/curl-$CURL_VERSION.tar.xz
https://mirrors.edge.kernel.org/pub/software/scm/git/git-$GIT_VERSION.tar.xz
https://www.musl-libc.org/releases/musl-$MUSL_VERSION.tar.gz
https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
https://www.zlib.net/zlib-$ZLIB_VERSION.tar.xz
https://github.com/libexpat/libexpat/releases/download/R_2_2_7/expat-$EXPAT_VERSION.tar.xz
https://sourceforge.net/projects/asciidoc/files/asciidoc/$ASCIIDOC_VERSION/asciidoc-$ASCIIDOC_VERSION.tar.gz
https://releases.pagure.org/xmlto/xmlto-$XMLTO_VERSION.tar.bz2
EOF
    )
}

while getopts cCDd:j:hp: name
do
    case $name in
    c) clean; exit 0;;
    C) distclean; exit 0;;
    D) download; exit 0;;
    h) usage; exit 0;;
    j) NJOBS="$OPTARG";;
    p) PREFIX="$OPTARG";;
    d) DESTDIR="$OPTARG";;
    ?) usage >&2; exit 1;;
    esac
done

clean

if [ ! -d download/ ]; then
    download
fi

mkdir -p "$DESTDIR$PREFIX" "$WORK/deps"

tar -C "$WORK" -xzf download/musl-$MUSL_VERSION.tar.gz
(
    mkdir -p "$WORK/musl"
    cd "$WORK/musl"
    ../musl-$MUSL_VERSION/configure \
        --prefix="$WORK/deps" \
        --enable-wrapper=gcc \
        --syslibdir="$WORK/deps/lib"
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xJf download/zlib-$ZLIB_VERSION.tar.xz
(
    mkdir -p "$WORK/zlib"
    cd "$WORK/zlib"
    ../zlib-$ZLIB_VERSION/configure \
        --prefix="$WORK/deps" \
        --static
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xzf download/openssl-$OPENSSL_VERSION.tar.gz
(
    cd "$WORK/openssl-$OPENSSL_VERSION"
    sed -i 's#linux/mman\.h#sys/mman.h#' crypto/mem_sec.c
    sed -i '/asm\/unistd\.h/d' crypto/rand/rand_unix.c
    mkdir -p "$WORK/openssl"
    cd "$WORK/openssl"
    ../openssl-$OPENSSL_VERSION/Configure \
        CC="$WORK/deps/bin/musl-gcc -idirafter /usr/include/" \
        --prefix="$WORK/deps" \
        --openssldir="$WORK/deps" \
        linux-x86_64 \
        no-shared
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xJf download/curl-$CURL_VERSION.tar.xz
(
    mkdir -p "$WORK/curl"
    cd "$WORK/curl"
    ../curl-$CURL_VERSION/configure \
        CC="$WORK/deps/bin/musl-gcc" \
        --prefix="$WORK/deps" \
        --enable-static \
        --disable-shared \
        --with-ssl="$WORK/deps"
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xJf download/expat-$EXPAT_VERSION.tar.xz
(
    mkdir -p "$WORK/expat"
    cd "$WORK/expat"
    ../expat-$EXPAT_VERSION/configure \
        CC="$WORK/deps/bin/musl-gcc" \
        --prefix="$WORK/deps" \
        --enable-static \
        --disable-shared \
        --without-docbook \
        --without-tests \
        --without-examples
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xzf download/asciidoc-$ASCIIDOC_VERSION.tar.gz
(
    cd "$WORK/asciidoc-$ASCIIDOC_VERSION"
    ./configure \
        CC="$WORK/deps/bin/musl-gcc" \
        --prefix="$WORK/deps"
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xjf download/xmlto-$XMLTO_VERSION.tar.bz2
(
    mkdir -p "$WORK/xmlto"
    cd "$WORK/xmlto"
    ../xmlto-$XMLTO_VERSION/configure \
        CC="$WORK/deps/bin/musl-gcc" \
        --prefix="$WORK/deps"
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xJf download/git-$GIT_VERSION.tar.xz
(
    cd "$WORK/git-$GIT_VERSION"
    ./configure \
        CC="$WORK/deps/bin/musl-gcc" \
        --prefix="$PREFIX" \
        --with-openssl="$WORK/deps" \
        --with-curl="$WORK/deps" \
        --with-zlib="$WORK/deps" \
        --with-expat="$WORK/deps" \
        LDFLAGS='-static -s' \
        LIBS='-lz -lcurl -lssl -lcrypto'
    make CURL_LIBCURL='-lcurl -lssl -lcrypto' -kj$NJOBS
    make CURL_LIBCURL='-lcurl -lssl -lcrypto' install
    PATH="$WORK/deps/bin:$PATH" make -kj$NJOBS doc
    PATH="$WORK/deps/bin:$PATH" make install-doc
)
