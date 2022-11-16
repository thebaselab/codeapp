import os
import re
from distutils.errors import DistutilsSetupError
from enum import IntEnum, auto
from typing import Dict, List, Optional, Union

import semantic_version


class Binding(IntEnum):
    """
    Enumeration of possible Rust binding types supported by `setuptools-rust`.

    Attributes:
        PyO3: This is an extension built using
            `PyO3 <https://github.com/pyo3/pyo3>`_.
        RustCPython: This is an extension built using
            `rust-cpython <https://github.com/dgrunwald/rust_cpython>`_.
        NoBinding: Bring your own bindings for the extension.
        Exec: Build an executable instead of an extension.
    """
    PyO3 = auto()
    RustCPython = auto()
    NoBinding = auto()
    Exec = auto()

    def __repr__(self):
         return f"{self.__class__.__name__}.{self.name}"


class Strip(IntEnum):
    """
    Enumeration of modes for stripping symbols from the built extension.

    Attributes:
        No: Do not strip symbols.
        Debug: Strip debug symbols.
        All: Strip all symbols.
    """
    No = auto()
    Debug = auto()
    All = auto()

    def __repr__(self):
         return f"{self.__class__.__name__}.{self.name}"


class RustExtension:
    """Used to define a rust extension module and its build configuration.

    Args:
        target: The full name of the extension, including any packages i.e.
            *not* a filename or pathname, but Python dotted name. It is possible to
            specify multiple binaries, if extension uses ``Binding.Exec`` binding mode.
            In that case first argument has to be dictionary. Keys of the
            dictionary corresponds to compiled rust binaries and values are full
            name of the executable inside python package.
        path: Path to the ``Cargo.toml`` manifest file
        args: A list of extra argumenents to be passed to cargo.
        features: A list of features to also build.
        rust_version: Minimum Rust compiler version required for this
            extension.
        quiet: Suppress Cargo's output.
        debug: Controls whether ``--debug`` or ``--release`` is passed to
            cargo. If set to `None` (the default) then build type is auto-detect.
            Inplace build is debug build otherwise release.
        binding: Controls which python binding is in use.
        strip: Strip symbols from final file. Does nothing for debug build.
        script: Generate console script for executable if ``Binding.Exec`` is
            used.
        native: Build extension or executable with ``--target-cpu=native``.
        optional: if it is true, a build failure in the extension will not
            abort the build process, but instead simply not install the failing
            extension.
        py_limited_api: Same as `py_limited_api` on
            `setuptools.Extension`. Note that if you set this to True, your extension
            must pass the appropriate feature flags to pyo3 (ensuring that `abi3`
            feature is enabled).
    """

    def __init__(
        self,
        target: Union[str, Dict[str, str]],
        path: str = "Cargo.toml",
        args: Optional[List[str]] = None,
        features: Optional[List[str]] = None,
        rustc_flags: Optional[List[str]] = None,
        rust_version: Optional[str] = None,
        quiet: bool = False,
        debug: Optional[bool] = None,
        binding: Binding = Binding.PyO3,
        strip: Strip = Strip.No,
        script: bool = False,
        native: bool = False,
        optional: bool = False,
        py_limited_api: bool = False,
    ):
        if isinstance(target, dict):
            name = "; ".join("%s=%s" % (key, val) for key, val in target.items())
        else:
            name = target
            target = {"": target}

        self.name = name
        self.target = target
        self.args = args
        self.rustc_flags = rustc_flags
        self.binding = binding
        self.rust_version = rust_version
        self.quiet = quiet
        self.debug = debug
        self.strip = strip
        self.script = script
        self.native = native
        self.optional = optional
        self.py_limited_api = py_limited_api
        # We pass this over to setuptools in one place, and it wants this
        # attribute to exist.
        self._links_to_dynamic = False

        if features is None:
            features = []

        self.features = [s.strip() for s in features]

        # get relative path to Cargo manifest file
        path = os.path.relpath(path)
        self.path = path

    def get_lib_name(self):
        """ Parse Cargo.toml to get the name of the shared library. """
        # We import in here to make sure the the setup_requires are already installed
        import toml

        cfg = toml.load(self.path)
        name = cfg.get("lib", {}).get("name")
        if name is None:
            name = cfg.get("package", {}).get("name")
        if name is None:
            raise Exception(
                "Can not parse library name from Cargo.toml. "
                "Cargo.toml missing value for 'name' key "
                "in both the [package] section and the [lib] section"
            )
        name = re.sub(r"[./\\-]", "_", name)
        return name

    def get_rust_version(self):
        if self.rust_version is None:
            return None
        try:
            return semantic_version.SimpleSpec.parse(self.rust_version)
        except ValueError:
            raise DistutilsSetupError(
                "Can not parse rust compiler version: %s", self.rust_version
            )

    def entry_points(self):
        entry_points = []
        if self.script and self.binding == Binding.Exec:
            for name, mod in self.target.items():
                base_mod, name = mod.rsplit(".")
                script = "%s=%s.%s:run" % (name, base_mod, "_gen_%s" % name)
                entry_points.append(script)

        return entry_points

    def install_script(self, ext_path):
        if self.script and self.binding == Binding.Exec:
            dirname, name = os.path.split(ext_path)
            file = os.path.join(dirname, "_gen_%s.py" % name)
            with open(file, "w") as f:
                f.write(TMPL.format({"name": name}))


TMPL = """
import os
import sys


def run():
    path = os.path.split(__file__)[0]
    name = os.path.split(sys.argv[0])[1]
    file = os.path.join(path, name)
    if os.path.isfile(file):
        os.execv(file, sys.argv)
    else:
        print("can't execute '{name}'")
"""
