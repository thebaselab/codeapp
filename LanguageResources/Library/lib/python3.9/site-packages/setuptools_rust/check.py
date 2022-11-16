import os
import sys
import subprocess
from distutils.errors import (
    CompileError,
    DistutilsFileError,
    DistutilsExecError,
)

import semantic_version

from .command import RustCommand
from .extension import RustExtension
from .utils import rust_features

MIN_VERSION = semantic_version.Spec(">=1.16")


class check_rust(RustCommand):
    """Run Rust check"""

    description = "check Rust extensions"

    def run(self):
        if "sdist" in self.distribution.commands:
            return

        super().run()

    def run_for_extension(self, ext: RustExtension):
        # Make sure that if pythonXX-sys is used, it builds against the current
        # executing python interpreter.
        bindir = os.path.dirname(sys.executable)

        env = os.environ.copy()
        env.update(
            {
                # disables rust's pkg-config seeking for specified packages,
                # which causes pythonXX-sys to fall back to detecting the
                # interpreter from the path.
                "PYTHON_2.7_NO_PKG_CONFIG": "1",
                "PATH": bindir + os.pathsep + os.environ.get("PATH", ""),
            }
        )

        if not os.path.exists(ext.path):
            raise DistutilsFileError(
                f"can't find Rust extension project file: {ext.path}"
            )

        features = set(ext.features)
        features.update(rust_features(binding=ext.binding))

        # check cargo command
        feature_args = ["--features", " ".join(features)] if features else []
        args = (
            ["cargo", "check", "--manifest-path", ext.path]
            + feature_args
            + list(ext.args or [])
        )

        # Execute cargo command
        try:
            subprocess.check_output(args)
        except subprocess.CalledProcessError as e:
            raise CompileError(
                "cargo failed with code: %d\n%s"
                % (e.returncode, e.output.decode("utf-8"))
            )
        except OSError:
            raise DistutilsExecError(
                "unable to execute 'cargo' - this package "
                "requires Rust to be installed and "
                "cargo to be on the PATH"
            )
        else:
            print(f"extension '{ext.name}' checked")
