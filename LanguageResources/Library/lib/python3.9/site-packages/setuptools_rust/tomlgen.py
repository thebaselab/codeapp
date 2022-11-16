# coding: utf-8
import configparser
import os
import string

import setuptools

from distutils import log
from distutils.command.build import build

from .extension import RustExtension


__all__ = ["tomlgen"]


class tomlgen_rust(setuptools.Command):

    description = "Generate `Cargo.toml` for Rust extensions"

    user_options = [
        (str("force"), str("f"), str("overwrite existing files if any")),
        (
            str("create-workspace"),
            str("w"),
            str("create a workspace file at the root of the project"),
        ),
        (
            str("no-config"),
            str("C"),
            str("do not create a `.cargo/config` file when generating a workspace"),
        ),
    ]

    boolean_options = [str("create_workspace"), str("force")]

    def initialize_options(self):

        self.dependencies = None
        self.authors = None
        self.create_workspace = None
        self.no_config = None
        self.force = None

        # use the build command to find build directories
        self.build = build(self.distribution)

        # parse config files
        self.cfg = configparser.ConfigParser()
        self.cfg.read(self.distribution.find_config_files())

    def finalize_options(self):

        # Finalize previous commands
        self.distribution.finalize_options()
        self.build.ensure_finalized()

        # Shortcuts
        self.extensions = self.distribution.rust_extensions
        self.workspace = os.path.abspath(
            os.path.dirname(self.distribution.script_name) or "."
        )

        # Build list of authors
        if self.authors is not None:
            sep = "\n" if "\n" in self.authors.strip() else ","
            self.authors = [author.strip() for author in self.authors.split(sep)]
        else:
            self.authors = [
                "{} <{}>".format(
                    self.distribution.get_author(),
                    self.distribution.get_author_email().strip("\"'"),
                )
            ]

    def run(self):
        import toml

        # Create a `Cargo.toml` for each extension
        for ext in self.extensions:
            if not os.path.exists(ext.path) or self.force:
                log.info("creating 'Cargo.toml' for '%s'", ext.name)
                with open(ext.path, "w") as manifest:
                    toml.dump(self.build_cargo_toml(ext), manifest)
            else:
                log.warn("skipping 'Cargo.toml' for '%s' -- already exists", ext.name)

        # Create a `Cargo.toml` for the project workspace
        if self.create_workspace and self.extensions:
            toml_path = os.path.join(self.workspace, "Cargo.toml")
            if not os.path.exists(toml_path) or self.force:
                log.info("creating 'Cargo.toml' for workspace")
                with open(toml_path, "w") as manifest:
                    toml.dump(self.build_workspace_toml(), manifest)
            else:
                log.warn("skipping 'Cargo.toml' for workspace -- already exists")

        # Create a `.cargo/config` file
        if self.create_workspace and self.extensions and not self.no_config:

            dist = self.distribution
            targetdir = os.path.join(self.build.build_temp, dist.get_name())
            cfgdir = os.path.abspath(
                os.path.join(os.getcwd(), dist.script_name, "..", ".cargo")
            )

            if not os.path.exists(os.path.join(cfgdir, "config")) or self.force:
                if not os.path.exists(cfgdir):
                    os.makedirs(cfgdir)
                with open(os.path.join(cfgdir, "config"), "w") as config:
                    log.info("creating '.cargo/config' for workspace")
                    toml.dump({
                        'build': {
                            'target-dir': os.path.relpath(targetdir)
                        },
                    }, config)
            else:
                log.warn("skipping '.cargo/config' -- already exists")

    def build_cargo_toml(self, ext):
        toml = {}

        # The directory where the extension's manifest is located
        tomldir = os.path.dirname(ext.path)

        # If the RustExtension was not created by `find_rust_extensions`
        # the `lib.rs` file is expected to be located near `Cargo.toml`
        if not hasattr(ext, "libfile"):
            ext.libfile = ext.path.replace("Cargo.toml", "lib.rs")

        # Create a small package section
        toml["package"] = {
            "name": ext.name.replace('.', '-'),
            "version": self.distribution.get_version(),
            "authors": self.authors,
            "publish": False,
            "edition": "2018"
        }

        # Add the relative path to the workspace if any
        if self.create_workspace:
            toml["package"]["workspace"] = os.path.relpath(self.workspace, tomldir)

        # Create a small lib section
        toml["lib"] = {
            "crate-type": ["cdylib"],
            "name": _slugify(ext.name),
            "path": os.path.relpath(ext.libfile, tomldir)
        }

        # Find dependencies within the `setup.cfg` file of the project
        toml["dependencies"] = {}
        for dep, options in self.iter_dependencies(ext):
            toml["dependencies"][dep] = options

        return toml

    def build_workspace_toml(self):

        # Find all members of the workspace
        members = [
            os.path.dirname(os.path.relpath(ext.path)) for ext in self.extensions
        ]

        return {
            "workspace": {
                "members": members
            }
        }

    def iter_dependencies(self, ext=None):
        import toml

        command = self.get_command_name()

        # global dependencies
        sections = ["{}.dependencies".format(command)]

        # extension-specific dependencies
        if ext is not None:
            sections.append("{}.dependencies.{}".format(command, ext.name))

        for section in sections:
            if self.cfg.has_section(section):
                for dep, options in self.cfg.items(section):
                    yield dep, toml.loads("%s = %s" % (dep, options))[dep]


def _slugify(name):
    allowed = set(string.ascii_letters + string.digits + "_")
    slug = [char if char in allowed else "_" for char in name]
    return "".join(slug)


def find_rust_extensions(*directories, **kwargs):
    """Attempt to find Rust extensions in given directories.

    This function will recurse through the directories in the given
    directories, to find a name whose name is ``libfile``. When such
    a file is found, an extension is created, expecting the cargo
    manifest file (``Cargo.toml``) to be next to that file. The
    extension destination will be deduced from the name of the
    directory where that ``libfile`` is contained.

    Arguments:
        directories (list, *optional*): a list of directories to walk
            through recursively to find extensions. If none are given,
            then the current directory will be used instead.

    Keyword Arguments:
        libfile (str): the name of the file to look for when searching
            for Rust extensions. Defaults to ``lib.rs``, but might be
            changed to allow defining more *Pythonic* filenames
            (like ``__init__.rs``)!

    Note:
        All other keyword arguments will be directly passed to the
        `RustExtension` instance created when an extension is found.
        One may be interested in passing ``bindings`` and ``strip``
        options::

            >>> import setuptools_rust as rust
            >>> rust.find_rust_extensions(binding=rust.Binding.PyO3)

    Example:

        Consider the following project::

            lib/
             └ mylib/
                 └ rustext/
                     ├ lib.rs
                     ├  ...
                     └  Cargo.toml
            setup.py

        There is only one extension that can be found in the ``lib``
        module::

            >>> import setuptools_rust as rust
            >>> for ext in rust.find_rust_extensions("lib"):
            ...     print(ext.name, "=>", ext.path)
            lib.mylib.rustext => lib/mylib/rustext/Cargo.toml
    """

    # Get the file used to mark a Rust extension
    libfile = kwargs.get("libfile", "lib.rs")

    # Get the directories to explore
    directories = directories or [os.getcwd()]

    extensions = []
    for directory in directories:
        for base, dirs, files in os.walk(directory):
            if libfile in files:
                dotpath = os.path.relpath(base).replace(os.path.sep, ".")
                tomlpath = os.path.join(base, "Cargo.toml")
                ext = RustExtension(dotpath, tomlpath, **kwargs)
                ext.libfile = os.path.join(base, libfile)
                extensions.append(ext)

    return extensions
