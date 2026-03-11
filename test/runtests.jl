using Visidata
using Pkg.TOML
using Test

const PROJECT          = TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
const VISIDATA_VERSION = PROJECT["visidata"]["version"]

@testset "visidata_bin" begin
    bin = visidata_bin()

    @test isfile(bin)

    @test if Sys.iswindows()
        endswith(bin, "vd.bat")
    else
        endswith(bin, "vd")
    end
end

@testset "visidata --version" begin
    bin = visidata_bin()
    cmd = Sys.iswindows() ? `cmd /c $bin --version` : `$bin --version`
    out = readchomp(cmd)
    @test contains(out, "VisiData")
    @test contains(out, VISIDATA_VERSION)
end
