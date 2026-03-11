# Builds the visidata artifact for the CURRENT platform and archives it to
# scripts/output/. Intended to run inside a CI matrix job (linux + windows)
# so each platform is built natively — no cross-compilation.
#
# Reads the VisiData version from [visidata] version in Project.toml.
# Hash is computed with Tar.tree_hash (same algorithm Julia uses to verify
# downloaded artifacts), avoiding the GitTools/isexecutable inconsistency
# on Windows where .exe files appear executable by extension but stat().mode
# has no exec bit.

using TOML
using Tar
using Downloads: download
using SHA

# ── Config ────────────────────────────────────────────────────────────────────

const PROJECT          = TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
const VISIDATA_VERSION = PROJECT["visidata"]["version"]

const PYTHON_URLS = Dict(
    "linux"   => "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "windows" => "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
)

const PLATFORM = Sys.iswindows() ? "windows" : "linux"
const OUT_DIR  = joinpath(@__DIR__, "output")
const TARBALL  = joinpath(OUT_DIR, "visidata-$PLATFORM-x86_64.tar.gz")

# ── Build ─────────────────────────────────────────────────────────────────────

function build(dir)
    url     = PYTHON_URLS[PLATFORM]
    archive = "cpython-$PLATFORM.tar.gz"

    println("  Downloading Python ($PLATFORM)")
    download(url, archive)
    println("  Extracting Python")
    run(`tar -xzf $archive -C $dir --strip-components=1`)
    rm(archive)

    if Sys.iswindows()
        python = joinpath(dir, "python.exe")
        println("  pip install visidata==$VISIDATA_VERSION")
        run(`$python -m pip install --no-cache-dir visidata==$VISIDATA_VERSION`)

        # pip's vd.exe hardcodes the build-time Python path — replace with a
        # .bat wrapper that locates Python relative to itself at runtime.
        vd_bat = joinpath(dir, "Scripts", "vd.bat")
        write(vd_bat, "@echo off\r\n\"%~dp0\\..\\python.exe\" -m visidata %*\r\n")
    else
        pip = joinpath(dir, "bin", "pip3")
        println("  pip install visidata==$VISIDATA_VERSION")
        run(`$pip install --no-cache-dir visidata==$VISIDATA_VERSION`)

        # Fix the pip-generated shebang — hardcodes the build-time path.
        vd = joinpath(dir, "bin", "vd")
        write(vd, "#!/bin/sh\nexec \"\$(dirname \"\$0\")/python3.13\" -m visidata \"\$@\"\n")
        chmod(vd, 0o755)
    end
end

# ── Main ──────────────────────────────────────────────────────────────────────

println("==> Building $PLATFORM artifact  (visidata $VISIDATA_VERSION)")
mkpath(OUT_DIR)

artifact_dir = mktempdir()
build(artifact_dir)

# Create an uncompressed tar using Julia's Tar package so that the metadata
# it stores matches exactly what Tar.tree_hash will read back.
println("==> Archiving")
uncompressed = tempname() * ".tar"
Tar.create(artifact_dir, uncompressed)
rm(artifact_dir, recursive=true)

# Compute git-tree-sha1 by reading the tar with Tar.tree_hash — the same
# function Julia's artifact system uses when verifying a downloaded tarball.
tree_hash_bytes = open(Tar.tree_hash, uncompressed)
tree_hash_hex   = bytes2hex(tree_hash_bytes)

# Gzip-compress to produce the final tarball.
open(TARBALL, "w") do out
    run(pipeline(`gzip -9n -c $uncompressed`, stdout=out))
end
rm(uncompressed)

sha256_hex = open(io -> bytes2hex(sha256(io)), TARBALL)

println("tree-hash: $tree_hash_hex")
println("sha256:    $sha256_hex")

if haskey(ENV, "GITHUB_OUTPUT")
    open(ENV["GITHUB_OUTPUT"], "a") do io
        println(io, "tree-hash=$tree_hash_hex")
        println(io, "sha256=$sha256_hex")
    end
end

write(joinpath(OUT_DIR, "tree-hash.txt"), tree_hash_hex)
write(joinpath(OUT_DIR, "sha256.txt"),    sha256_hex)
