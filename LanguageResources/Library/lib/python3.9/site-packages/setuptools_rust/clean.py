import sys
import subprocess

from .command import RustCommand
from .extension import RustExtension

class clean_rust(RustCommand):
    """Clean Rust extensions. """

    description = "clean Rust extensions (compile/link to build directory)"

    def initialize_options(self):
        super().initialize_options()
        self.inplace = False

    def run_for_extension(self, ext: RustExtension):
        # build cargo command
        args = ["cargo", "clean", "--manifest-path", ext.path]

        if not ext.quiet:
            print(" ".join(args), file=sys.stderr)

        # Execute cargo command
        try:
            subprocess.check_output(args)
        except:
            pass
