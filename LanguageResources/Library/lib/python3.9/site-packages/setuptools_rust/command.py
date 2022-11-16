from abc import ABC, abstractmethod

from distutils.cmd import Command
from distutils.errors import DistutilsPlatformError

from .extension import RustExtension
from .utils import get_rust_version

class RustCommand(Command, ABC):
    """Abstract base class for commands which interact with Rust Extensions."""

    def initialize_options(self):
        self.extensions = ()

    def finalize_options(self):
        self.extensions = [
            ext
            for ext in self.distribution.rust_extensions
            if isinstance(ext, RustExtension)
        ]

    def run(self):
        if not self.extensions:
            return

        all_optional = all(ext.optional for ext in self.extensions)
        try:
            version = get_rust_version(
                min_version=max(
                    filter(
                        lambda version: version is not None,
                        (ext.get_rust_version() for ext in self.extensions),
                    ),
                    default=None
                )
            )
        except DistutilsPlatformError as e:
            if not all_optional:
                raise
            else:
                print(str(e))
                return

        for ext in self.extensions:
            try:
                rust_version = ext.get_rust_version()
                if rust_version is not None and version not in rust_version:
                    raise DistutilsPlatformError(
                        f"Rust {version} does not match extension requirement {rust_version}"
                    )

                self.run_for_extension(ext)
            except Exception as e:
                if not ext.optional:
                    raise
                else:
                    command_name = self.get_command_name()
                    print(f"{command_name}: optional Rust extension {ext.name} failed")
                    print(str(e))

    @abstractmethod
    def run_for_extension(self, extension: RustExtension) -> None:
        ...
