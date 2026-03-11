using Visidata
using Test

@testset "visidata_bin" begin
    bin = visidata_bin()

    @test isfile(bin)

    @test if Sys.iswindows()
        endswith(bin, "python.exe")
    else
        endswith(bin, "vd")
    end

    # Check visidata is installed and reports its version
    out = if Sys.iswindows()
        readchomp(`$bin -m visidata --version`)
    else
        readchomp(`$bin --version`)
    end
    @test contains(out, "VisiData")
end
