# Maintainer script: builds visidata artifacts for Linux and Windows, uploads
# the tarballs to a GitHub Release, and writes Artifacts.toml.
#
# The release tag is derived from VISIDATA_VERSION below — update that constant
# when upgrading visidata and re-run the script.
#
# Requirements:
#   - Run on Linux (Windows artifact is cross-built via pip --target)
#   - `gh` CLI installed and authenticated
#   - A GitHub Release must already exist for the tag (vX.Y.Z)
#
# Usage:
#   julia scripts/build_artifacts.jl

using Pkg.Artifacts
using Downloads: download
using SHA

# ── Config ────────────────────────────────────────────────────────────────────

const ARTIFACT_NAME    = "visidata"
const VISIDATA_VERSION = "3.1.1"   # ← bump this to upgrade
const TAG              = "v$VISIDATA_VERSION"

const LINUX_PYTHON_URL = "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
const WINDOWS_PYTHON_URL = "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-pc-windows-msvc-install_only_stripped.tar.gz"

const REPO = "sandyspiers/Visidata.jl"
const ARTIFACT_TOML = joinpath(@__DIR__, "..", "Artifacts.toml")
const OUT_DIR = joinpath(@__DIR__, "output")

# ── Helpers ───────────────────────────────────────────────────────────────────

function tarball_sha256(path)
    open(path, "r") do io
        bytes2hex(sha256(io))
    end
end

function fetch_python(url, dest_tarball, extract_dir)
    mkpath(extract_dir)
    println("  Downloading $url")
    download(url, dest_tarball)
    println("  Extracting")
    run(`tar -xzf $dest_tarball -C $extract_dir --strip-components=1`)
    rm(dest_tarball)
end

# ── Platform builders ─────────────────────────────────────────────────────────

function build_linux()
    println("==> Building Linux artifact")
    hash = create_artifact() do artifact_dir
        fetch_python(LINUX_PYTHON_URL, "cpython-linux.tar.gz", artifact_dir)
        pip = joinpath(artifact_dir, "bin", "pip3")
        println("  pip install visidata==$VISIDATA_VERSION")
        run(`$pip install --no-cache-dir visidata==$VISIDATA_VERSION`)

        # Replace the pip-generated vd script: its shebang points to the
        # temporary build-time artifact path, which won't exist at runtime.
        # Use a portable wrapper that resolves python relative to itself.
        vd = joinpath(artifact_dir, "bin", "vd")
        @assert isfile(vd)
        write(vd, """
            #!/bin/sh
            exec "\$(dirname "\$0")/python3.13" -m visidata "\$@"
            """)
        chmod(vd, 0o755)
    end
    return hash
end

function build_windows(linux_pip)
    println("==> Building Windows artifact (cross-install via Linux pip)")
    hash = create_artifact() do artifact_dir
        fetch_python(WINDOWS_PYTHON_URL, "cpython-windows.tar.gz", artifact_dir)

        site_packages = joinpath(artifact_dir, "Lib", "site-packages")
        mkpath(site_packages)
        println("  pip install visidata==$VISIDATA_VERSION --target $site_packages")
        run(`$linux_pip install --no-cache-dir --target $site_packages visidata==$VISIDATA_VERSION`)

        # Windows launcher scripts
        scripts_dir = joinpath(artifact_dir, "Scripts")
        mkpath(scripts_dir)
        write(joinpath(scripts_dir, "vd.cmd"), "@echo off\r\n\"%~dp0..\\python.exe\" -m visidata %*\r\n")
        cp(joinpath(artifact_dir, "python.exe"), joinpath(scripts_dir, "vd.exe"); force=true)
    end
    return hash
end

# ── Main ──────────────────────────────────────────────────────────────────────

isempty(ARGS) || (println("Usage: julia scripts/build_artifacts.jl  (no arguments — tag is derived from VISIDATA_VERSION)"); exit(1))

println("==> Release tag: $TAG")
mkpath(OUT_DIR)

# Build
linux_hash = build_linux()
linux_pip = joinpath(artifact_path(linux_hash), "bin", "pip3")
windows_hash = build_windows(linux_pip)

# Archive
linux_tarball = joinpath(OUT_DIR, "visidata-linux-x86_64.tar.gz")
windows_tarball = joinpath(OUT_DIR, "visidata-windows-x86_64.tar.gz")

println("==> Archiving artifacts")
archive_artifact(linux_hash, linux_tarball)
archive_artifact(windows_hash, windows_tarball)

linux_sha256 = tarball_sha256(linux_tarball)
windows_sha256 = tarball_sha256(windows_tarball)

# Create (or recreate) GitHub Release and upload tarballs
println("==> Creating GitHub Release $TAG")
success(`gh release delete $TAG --repo $REPO --yes --cleanup-tag`)
run(`gh release create $TAG --repo $REPO --title "visidata $VISIDATA_VERSION" --notes "Bundled visidata $VISIDATA_VERSION artifact."`)
run(`gh release upload $TAG $linux_tarball $windows_tarball --repo $REPO`)

linux_url = "https://github.com/$REPO/releases/download/$TAG/visidata-linux-x86_64.tar.gz"
windows_url = "https://github.com/$REPO/releases/download/$TAG/visidata-windows-x86_64.tar.gz"

# Write Artifacts.toml
println("==> Writing Artifacts.toml")
bind_artifact!(ARTIFACT_TOML, ARTIFACT_NAME, linux_hash;
    platform=Base.BinaryPlatforms.Platform("x86_64", "linux"),
    download_info=[(linux_url, linux_sha256)],
    lazy=true,
    force=true)

bind_artifact!(ARTIFACT_TOML, ARTIFACT_NAME, windows_hash;
    platform=Base.BinaryPlatforms.Platform("x86_64", "windows"),
    download_info=[(windows_url, windows_sha256)],
    lazy=true,
    force=true)

println("""
Done!
  Linux:   $linux_url  [$linux_sha256]
  Windows: $windows_url  [$windows_sha256]

Commit Artifacts.toml and push.
""")
