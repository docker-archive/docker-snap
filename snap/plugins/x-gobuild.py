import os
import subprocess
import sys

import snapcraft


def list_executables(dir):
    """Return a list of the executable files under `dir`."""
    output = subprocess.check_output(
        ['find', dir, '-executable', '-type', 'f'])
    r = set()
    for line in output.splitlines():
        r.add(line.decode(sys.getfilesystemencoding()))
    return r


def is_dynamic_executable(path):
    """Is `path` a dynamic executable?"""
    from elftools.elf.elffile import ELFFile
    from elftools.common.exceptions import ELFError
    # This way of answering the question is perhaps a bit OTT. But it works.
    try:
        e = ELFFile(open(path, 'rb'))
        return 'PT_DYNAMIC' in [s.header.p_type for s in e.iter_segments()]
    except ELFError as e:
        print("ELFFile({}) failed {}".format(path, e))
        return False


class XGobuildPlugin(snapcraft.BasePlugin):
    def build(self):
        env = os.environ.copy()

        # Bootstrap with the go that is on the PATH.
        goroot_bootstrap = subprocess.check_output(['go', 'env', 'GOROOT'])
        env['GOROOT_BOOTSTRAP'] = goroot_bootstrap.decode(sys.getfilesystemencoding()).rstrip('\n')
        # Set GOROOT_FINAL to something that should work (we don't
        # know the actual GOROOT until the package is uploaded to the
        # store, sadly).
        env['GOROOT_FINAL'] = '/snap/go/current'
        # But set GOROOT for now so that things continue to work.
        env['GOROOT'] = self.builddir
        arch = os.popen('dpkg --print-architecture').read().strip()
        if arch == 'amd64' or arch == 'i386':
            # Mystical incantation so that the C object files that end
            # up in e.g. runtime/cgo.a can be processed by the system
            # linker on trusty.
            env['CGO_CFLAGS'] = "-Wa,-mrelax-relocations=no"

        # All dynamic executables in a classic snap must be linked
        # with special flags.  The Go linker does not support
        # equivalents of all these flags, so we need to link all
        # dynamic executables with the system linker. Unfortunately
        # GO_LDFLAGS='-linkmode=external' ./make.bash doesn't actually
        # work correctly on all platforms (the cgo stuff does not get
        # built early enough) so we bootstrap normally then relink
        # any dynamic binaries with the right flags.

        binaries_before = list_executables(self.builddir)
        self.run(['./make.bash'], cwd=os.path.join(self.builddir, 'src'), env=env)
        self.run(['rm', '-rf', 'pkg/bootstrap'], cwd=self.builddir)
        new_binaries = list_executables(self.builddir) - binaries_before

        # For extra fun, the special flags we need to link with are
        # not easily available from here -- they are exported as
        # $LDFLAGS inside self.run. But the go tool doesn't care about
        # $LDFLAGS, so we create a wrapper that does and tell the go
        # tool to invoke that instead.

        builtgo = os.path.join(self.builddir, 'bin', 'go')
        mycc = os.path.join(self.builddir, 'mycc')
        with open(mycc, 'w') as script:
            os.chmod(script.fileno(), 0o755)
            script.write('#!/bin/bash\n')
            script.write('set -ex\n')
            script.write('exec gcc $LDFLAGS "$@"\n')

        try:
            ldflags = '-linkmode=external -extld={}'.format(mycc)
            # Find any newly created dynamic binaries and rebuild them.
            for binary in new_binaries:
                if not is_dynamic_executable(binary):
                    continue
                bn = os.path.basename(binary)
                pkg = 'cmd/' + bn
                self.run(
                    [builtgo, 'build', '-v', '-ldflags', ldflags, pkg],
                    cwd=self.builddir, env=env)
                os.rename(os.path.join(self.builddir, bn), binary)
        finally:
            # Remove our gcc wrapper.
            os.unlink(mycc)

        # Just ship the whole tree.
        self.run(['rsync', '-a', '--exclude', '.git', self.builddir + '/', self.installdir])

        # And finally, create a wrapper that sets $GOROOT based on $SNAP.
        with open(os.path.join(self.installdir, 'gowrapper'), 'w') as script:
            os.chmod(script.fileno(), 0o755)
            script.write('#!/bin/bash\n')
            script.write('export GOROOT="$SNAP"\n')
            script.write('exec $SNAP/bin/go "$@"\n')
