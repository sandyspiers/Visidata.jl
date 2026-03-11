# Builds the visidata artifact for the CURRENT platform and writes the tarball
# plus tree-hash.txt / sha256.txt to scripts/output/.
#
# Hash is computed with Tar.tree_hash (the same algorithm Julia's artifact
# system uses for verification), avoiding the GitTools/isexecutable
# inconsistency on Windows where .exe files look executable by extension but
# stat().mode has no exec bit.

using TOML
using Tar
using Downloads: download
using SHA

const VISIDATA_VERSION = TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))["visidata"]["version"]

const PYTHON_URLS = Dict(
    "linux" => "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "windows" => "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
)

const PLATFORM = Sys.iswindows() ? "windows" : "linux"
const OUT_DIR = joinpath(@__DIR__, "output")
const TARBALL = joinpath(OUT_DIR, "visidata-$PLATFORM-x86_64.tar.gz")

println("==> Building $PLATFORM artifact  (visidata $VISIDATA_VERSION)")
mkpath(OUT_DIR)
dir = mktempdir()

println("  Downloading Python ($PLATFORM)")
download(PYTHON_URLS[PLATFORM], "cpython.tar.gz")
println("  Extracting Python")
run(`tar -xzf cpython.tar.gz -C $dir --strip-components=1`)
rm("cpython.tar.gz")

println("  pip install visidata==$VISIDATA_VERSION")
if Sys.iswindows()
    run(`$(joinpath(dir, "python.exe")) -m pip install --no-cache-dir visidata==$VISIDATA_VERSION`)
    # pip's vd.exe hardcodes the build-time Python path — replace with a
    # .bat wrapper that locates Python relative to itself at runtime.
    write(joinpath(dir, "Scripts", "vd.bat"),
        "@echo off\r\n\"%~dp0\\..\\python.exe\" -m visidata %*\r\n")
else
    run(`$(joinpath(dir, "bin", "pip3")) install --no-cache-dir visidata==$VISIDATA_VERSION`)
    # Fix the pip-generated shebang — it hardcodes the build-time path.
    vd = joinpath(dir, "bin", "vd")
    write(vd, "#!/bin/sh\nexec \"\$(dirname \"\$0\")/python3.13\" -m visidata \"\$@\"\n")
    chmod(vd, 0o755)
end

println("==> Archiving")
uncompressed = tempname() * ".tar"
Tar.create(dir, uncompressed)
rm(dir, recursive=true)

tree_hash_hex = open(Tar.tree_hash, uncompressed)
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
write(joinpath(OUT_DIR, "sha256.txt"), sha256_hex)
