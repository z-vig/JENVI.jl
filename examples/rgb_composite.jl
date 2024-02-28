using CairoMakie
using Colors
using HDF5
using JENVI
using Statistics
using StatsBase
CairoMakie.activate!(type="png")

function clip_im!(im::Array{<:AbstractFloat,2},minval::Float64,maxval::Float64)
    im[im.<minval] .= minval
    im[im.>maxval] .= maxval
end

function make_rgb()
    ibd1,ibd2,albedo,shadowmask = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5") do f
        println(keys(f["ScalarDatasets"]))
        λ = read_attribute(f,"smooth_wavelengths")
        return (
                f["ScalarDatasets/IBD_789_1309"][:,:],
                f["ScalarDatasets/IBD_1658_2498"][:,:],
                f["ScalarDatasets/band_ratio"][:,:],
                BitMatrix(f["ShadowMaps/lowsignal_shadows"][:,:])
            )
    end

    #println(size(ibd1),size(ibd2),size(albedo))
    upper_clip = 0.95
    lower_clip = 0.05
    clip_im!(ibd1,quantile(vec(ibd1),lower_clip),quantile(vec(ibd1),upper_clip))
    clip_im!(ibd2,quantile(vec(ibd2),lower_clip),quantile(vec(ibd2),upper_clip))
    clip_im!(albedo,quantile(vec(albedo),lower_clip),quantile(vec(albedo),upper_clip))

    StatsBase.transform!(StatsBase.fit(UnitRangeTransform,ibd1),ibd1)
    StatsBase.transform!(StatsBase.fit(UnitRangeTransform,ibd2),ibd2)
    StatsBase.transform!(StatsBase.fit(UnitRangeTransform,albedo),albedo)

    println(extrema(ibd1),extrema(ibd2),extrema(albedo))

    rgb_array = Matrix{RGB}(undef,(size(ibd1)))
    rgb_array .= [RGB(ibd1[i],ibd2[i],albedo[i]) for i in CartesianIndices(size(ibd1))]
    rgb_array[shadowmask] .= RGB(0.2,0.05,0)

    f = Figure(backgroundcolor = :transparent)
    ax = Axis(f[1,1])
    hidedecorations!(ax)
    hidespines!(ax)
    image!(ax,rgb_array,interpolate=false)

    CairoMakie.save("G:/Shared drives/Zach Lunar-VISE/Research Presentations/LPSC24/RGB_composite.png",f,size=(500,500))

    f
end

@time make_rgb()

