using Visidata
using Test

@testset "visidata_bin" begin
    bin = visidata_bin()

    @test isfile(bin)

    @test if Sys.iswindows()
        endswith(bin, "vd.exe")
    else
        endswith(bin, "vd")
    end

    # Check it runs and reports the expected version
    out = readchomp(`$bin --version`)
    @test contains(out, "visidata")
end
