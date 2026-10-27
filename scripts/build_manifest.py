"""Record the checked-out source and generated firmware hashes after a build.

Usage: python scripts/build_manifest.py BUILD_DIRECTORY [SOURCE_REPOSITORY]
The source repository defaults to the repository containing this script.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

build = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(["git", "-C", str(root), *args]).decode().strip()


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest() if hasattr(hashlib, "file_digest") else hashlib.sha256(stream.read()).hexdigest()


suffixes = {".v", ".vhd", ".sv", ".xdc", ".edf", ".xcix", ".xpr", ".tcl"}
inputs = {
    name: sha256(root / name)
    for name in git("ls-files").splitlines()
    if Path(name).suffix in suffixes
}
artifacts = {}
for name in ("main.bit", "main.bin", "routed.dcp", "timing.rpt", "check_timing.rpt", "design_info.txt"):
    path = build / name
    if not path.is_file():
        raise SystemExit(f"Build incomplete: {path} is missing")
    artifacts[name] = {"sha256": sha256(path), "bytes": path.stat().st_size}

manifest = {
    "branch": git("branch", "--show-current"),
    "commit": git("rev-parse", "HEAD"),
    "tracked_changes": git("status", "--porcelain", "--untracked-files=no"),
    "source_files_sha256": inputs,
    "artifacts": artifacts,
    "design_info": (build / "design_info.txt").read_text(),
    "hardware_tested": False,
}
if manifest["tracked_changes"]:
    raise SystemExit("Commit the source changes before recording a reproducible build")
(build / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
print(f"{manifest['branch']} {manifest['commit'][:12]}: {artifacts['main.bin']['sha256']}")
