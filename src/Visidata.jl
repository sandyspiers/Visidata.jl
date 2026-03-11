module Visidata

using Artifacts

export visidata_bin, visidata

"""
    visidata_bin() -> String

Return the path to the `vd` executable from the visidata artifact.
"""
function visidata_bin()
    art = artifact"visidata"
    bin = if Sys.iswindows()
        joinpath(art, "Scripts", "vd.exe")
    else
        joinpath(art, "bin", "vd")
    end
    isfile(bin) || error("vd binary not found at $bin")
    return bin
end

"""
    visidata(csvs...)

Launch visidata with the given file paths.
"""
function visidata(csvs...)
    run(`$(visidata_bin()) $csvs`)
end

end # module Visidata
