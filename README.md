# Lean, static Git build for Linux

This script builds Git from source, statically linked against OpenSSL.

The installation prefix is hardcoded in the binaries, so the build
*probably* should not be moved around, but, outside of `help`, it seems
to work fine anyway. Due to static linking, the binaries will work on
any Linux system with the same architecture so long as it's been
installed to the same prefix. The script's `-p` option controls the
install prefix, which defaults to `$PWD/git/`. The `-d` option sets
`DESTDIR` to stage for packaging.

If AsciiDoc is installed, the documentation will also be built and
installed.

## Usage

You don't need to be root, and the system itself remains untouched. If
you pre-populate `download/` then you don't even need internet access.

    $ ./build.sh

It will download all the source tarballs on the first run and re-use
them for repeated builds.
