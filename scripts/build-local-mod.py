"""Compile the G0 instrumentation against the jars already installed by HMCL.

This is a local bootstrap build. Gradle/Loom remains the intended reproducible build.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLATFORM = json.loads((ROOT / "config" / "platform.json").read_text(encoding="utf-8"))
HMCL_GAME = Path(PLATFORM["hmclRoot"]) / ".minecraft"
INSTANCE = HMCL_GAME / "versions" / PLATFORM["hmclInstance"]
MC_JAR = INSTANCE / f"{PLATFORM['hmclInstance']}.jar"
API_JAR = INSTANCE / "mods" / f"fabric-api-{PLATFORM['fabricApiVersion']}.jar"
LOADER_JAR = (
    HMCL_GAME
    / "libraries"
    / "net"
    / "fabricmc"
    / "fabric-loader"
    / PLATFORM["fabricLoaderVersion"]
    / f"fabric-loader-{PLATFORM['fabricLoaderVersion']}.jar"
)
SLF4J_JAR = HMCL_GAME / "libraries/org/slf4j/slf4j-api/2.0.1/slf4j-api-2.0.1.jar"
BUILD = ROOT / "build" / "local"
DEPS = BUILD / "deps"
CLASSES = BUILD / "classes"
RESOURCES = BUILD / "resources"
OUTPUT = BUILD / f"explorerlab-{PLATFORM['minecraftVersion']}-{PLATFORM['fabricLoaderVersion']}-0.1.0.jar"


def check_hashes() -> None:
    expected = {}
    for line in (ROOT / "config" / "installed-artifacts.sha256").read_text().splitlines():
        digest, name = line.split(maxsplit=1)
        expected[name.strip()] = digest.lower()
    for path in (MC_JAR, API_JAR, LOADER_JAR):
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected[path.name]:
            raise RuntimeError(f"Installed artifact hash changed: {path}")


def main() -> None:
    for path in (MC_JAR, API_JAR, LOADER_JAR, SLF4J_JAR):
        if not path.is_file():
            raise FileNotFoundError(path)
    check_hashes()
    if BUILD.exists():
        resolved_build = BUILD.resolve()
        resolved_root = ROOT.resolve()
        if BUILD.is_symlink() or resolved_root not in resolved_build.parents or resolved_build.name != "local":
            raise RuntimeError(f"Refusing to replace unexpected build directory: {resolved_build}")
        shutil.rmtree(BUILD)
    DEPS.mkdir(parents=True)
    CLASSES.mkdir()
    RESOURCES.mkdir()

    nested = (
        "fabric-api-base-0.92.12.jar",
        "fabric-lifecycle-events-v1-0.92.12.jar",
    )
    with zipfile.ZipFile(API_JAR) as archive:
        for name in nested:
            (DEPS / name).write_bytes(archive.read(f"META-INF/jars/{name}"))

    java_bin = Path(PLATFORM["javaHome"]) / "bin"
    classpath = ";".join(str(p) for p in (MC_JAR, LOADER_JAR, SLF4J_JAR, *DEPS.glob("*.jar")))
    sources = [str(p) for p in (ROOT / "src" / "main" / "java").rglob("*.java")]
    subprocess.run(
        [str(java_bin / "javac.exe"), "--release", "17", "-cp", classpath, "-d", str(CLASSES), *sources],
        check=True,
    )

    source_manifest = ROOT / "src" / "main" / "resources" / "fabric.mod.json"
    mod_json = json.loads(source_manifest.read_text(encoding="utf-8").replace("${version}", "0.1.0"))
    (RESOURCES / "fabric.mod.json").write_text(
        json.dumps(mod_json, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    subprocess.run(
        [str(java_bin / "jar.exe"), "--create", "--file", str(OUTPUT), "-C", str(CLASSES), ".", "-C", str(RESOURCES), "."],
        check=True,
    )
    with zipfile.ZipFile(OUTPUT) as archive:
        assert "org/explorerlab/ExplorerLabMod.class" in archive.namelist()
        assert json.loads(archive.read("fabric.mod.json"))["version"] == "0.1.0"
    print(OUTPUT)
    print("sha256", hashlib.sha256(OUTPUT.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
