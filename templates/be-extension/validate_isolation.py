#!/usr/bin/env python3
"""Architecture test: Verify extension isolation rules.

CI で実行し、ext 間の不正な import を検出する。
import-linter と併用することを推奨。

Usage:
    python validate_isolation.py [--src-dir SRC_DIR]
"""
import ast
import argparse
import sys
from pathlib import Path


def check_extension_imports(ext_dir: Path) -> list[str]:
    """指定 ext ディレクトリ内の .py ファイルを走査し、
    他 ext への import を検出する。
    """
    violations = []
    ext_name = ext_dir.name

    for py_file in ext_dir.rglob("*.py"):
        try:
            tree = ast.parse(py_file.read_text())
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                module = (
                    node.module if isinstance(node, ast.ImportFrom) else None
                )
                if module and "extensions." in module:
                    imported_ext = module.split("extensions.")[1].split(".")[0]
                    if imported_ext != ext_name:
                        violations.append(
                            f"{py_file}:{node.lineno} "
                            f"imports from extensions.{imported_ext}"
                        )
    return violations


def check_shared_imports(shared_dir: Path) -> list[str]:
    """shared/ 内のファイルが extensions/ を import していないか検証。"""
    violations = []

    for py_file in shared_dir.rglob("*.py"):
        try:
            tree = ast.parse(py_file.read_text())
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                module = (
                    node.module if isinstance(node, ast.ImportFrom) else None
                )
                if module and "extensions." in module:
                    violations.append(
                        f"{py_file}:{node.lineno} "
                        f"shared imports from extensions"
                    )
    return violations


def check_core_imports(core_dir: Path) -> list[str]:
    """core/ 内のファイルが extensions/ を import していないか検証。"""
    violations = []

    for py_file in core_dir.rglob("*.py"):
        try:
            tree = ast.parse(py_file.read_text())
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                module = (
                    node.module if isinstance(node, ast.ImportFrom) else None
                )
                if module and "extensions." in module:
                    violations.append(
                        f"{py_file}:{node.lineno} "
                        f"core imports from extensions"
                    )
    return violations


def main():
    parser = argparse.ArgumentParser(description="Validate extension isolation")
    parser.add_argument("--src-dir", default="src", help="Source directory (default: src)")
    args = parser.parse_args()

    src = Path(args.src_dir)
    ext_root = src / "extensions"
    shared_root = src / "shared"
    core_root = src / "core"
    all_violations = []

    if ext_root.exists():
        for ext_dir in sorted(ext_root.iterdir()):
            if ext_dir.is_dir() and not ext_dir.name.startswith("_"):
                all_violations.extend(check_extension_imports(ext_dir))

    if shared_root.exists():
        all_violations.extend(check_shared_imports(shared_root))

    if core_root.exists():
        all_violations.extend(check_core_imports(core_root))

    if all_violations:
        print("ISOLATION VIOLATIONS FOUND:")
        for v in all_violations:
            print(f"  - {v}")
        sys.exit(1)
    else:
        print("All isolation checks passed.")


if __name__ == "__main__":
    main()
