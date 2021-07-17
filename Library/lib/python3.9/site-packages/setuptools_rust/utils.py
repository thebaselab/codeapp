import sys
import subprocess
from distutils.errors import DistutilsPlatformError

import semantic_version

from .extension import Binding


def rust_features(ext=True, binding=Binding.PyO3):
    version = sys.version_info

    if binding in (Binding.NoBinding, Binding.Exec):
        return ()
    elif binding is Binding.PyO3:
        if version >= (3, 6):
            if ext:
                return {"pyo3/extension-module"}
            else:
                return {}
        else:
            raise DistutilsPlatformError(f"unsupported python version: {sys.version}")
    elif binding is Binding.RustCPython:
        if (3, 3) < version:
            if ext:
                return {"cpython/python3-sys", "cpython/extension-module"}
            else:
                return {"cpython/python3-sys"}
        else:
            raise DistutilsPlatformError(f"unsupported python version: {sys.version}")
    else:
        raise DistutilsPlatformError(f"unknown Rust binding: '{binding}'")


def get_rust_version(min_version=None):
    try:
        output = subprocess.check_output(["rustc", "-V"]).decode("latin-1")
        return semantic_version.Version(output.split(" ")[1], partial=True)
    except (subprocess.CalledProcessError, OSError):
        raise DistutilsPlatformError(
            "can't find Rust compiler\n\n"
            "If you are using an outdated pip version, it is possible a "
            "prebuilt wheel is available for this package but pip is not able "
            "to install from it. Installing from the wheel would avoid the "
            "need for a Rust compiler.\n\n"
            "To update pip, run:\n\n"
            "    pip install --upgrade pip\n\n"
            "and then retry package installation.\n\n"
            "If you did intend to build this package from source, try "
            "installing a Rust compiler from your system package manager and "
            "ensure it is on the PATH during installation. Alternatively, "
            "rustup (available at https://rustup.rs) is the recommended way "
            "to download and update the Rust compiler toolchain."
            + (

                f"\n\nThis package requires Rust {min_version}."
                if min_version is not None
                else ""
            )
        )
    except Exception as exc:
        raise DistutilsPlatformError(f"can't get rustc version: {str(exc)}")


def get_rust_target_info():
    output = subprocess.check_output(["rustc", "--print", "cfg"])
    return output.splitlines()
