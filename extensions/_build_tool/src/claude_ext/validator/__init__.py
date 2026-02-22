"""Extension validation system."""

from __future__ import annotations

from pathlib import Path

from ..models import ExtensionManifest
from .conflicts import ConflictValidator
from .isolation import IsolationValidator
from .schema import SchemaValidator


class ExtensionValidator:
    """Orchestrates all validators across all discovered extensions."""

    def __init__(self) -> None:
        self.schema = SchemaValidator()
        self.isolation = IsolationValidator()
        self.conflicts = ConflictValidator()

    def validate_all(
        self, extensions: list[tuple[Path, ExtensionManifest]]
    ) -> list[str]:
        """Run every validator on every extension and return accumulated errors."""
        all_errors: list[str] = []
        all_ext_dict = {m.name: m for _, m in extensions}

        for ext_dir, manifest in extensions:
            all_errors.extend(self.schema.validate(manifest, ext_dir))
            all_errors.extend(
                self.isolation.validate(manifest.name, ext_dir, all_ext_dict)
            )

        all_errors.extend(
            self.conflicts.validate([(m.name, m) for _, m in extensions])
        )

        return all_errors
