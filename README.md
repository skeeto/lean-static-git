# Lean, static Git build for Linux

This script builds Git and all of its native dependencies from source
with static linking. OpenSSL is linked instead of GnuTLS. The build time
dependencies are GCC and Python 2 (for AsciiDoc). Perl 5 is required at
run time.

Due to static linking, the binaries will work on any Linux system with
the same architecture so long as it's been installed to the same prefix.
The script's `-p` option controls the install prefix, which defaults to
`$PWD/git/`. The `-d` option sets `DESTDIR` to stage for packaging.

## Usage

You don't need to be root, and the system itself remains untouched. If
you pre-populate `download/` then you don't even need internet access.

    $ ./build.sh

It will download all the source tarballs on the first run and re-use
them for repeated builds.
