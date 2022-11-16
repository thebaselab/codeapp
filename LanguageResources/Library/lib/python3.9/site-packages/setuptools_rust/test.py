import os
import sys
import subprocess
from distutils.cmd import Command
from distutils.errors import CompileError, DistutilsFileError, DistutilsExecError

import semantic_version

from .extension import RustExtension
from .utils import rust_features, get_rust_version

MIN_VERSION = semantic_version.Spec(">=1.15")


class test_rust(Command):
    """Run cargo test"""

    description = "test Rust extensions"

    user_options = []

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
        features.update(rust_features(ext=False, binding=ext.binding))

        # test cargo command
        feature_args = ["--features", " ".join(features)] if features else []
        args = (
            ["cargo", "test", "--manifest-path", ext.path]
            + feature_args
            + list(ext.args or [])
        )

        # Execute cargo command
        print(" ".join(args))
        try:
            subprocess.check_output(args, env=env)
        except subprocess.CalledProcessError as e:
            raise CompileError(
                "cargo failed with code: %d\n%s"
                % (e.returncode, e.output.decode("utf-8"))
            )
        except OSError:
            raise DistutilsExecError(
                "Unable to execute 'cargo' - this package "
                "requires Rust to be installed and "
                "cargo to be on the PATH"
            )
        else:
            print(f"test completed for '{ext.name}' extension")
