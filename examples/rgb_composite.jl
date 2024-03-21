using CairoMakie
using Colors
using HDF5
using JENVI
using Statistics
using StatsBase
using DSP
using LinearAlgebra
CairoMakie.activate!(type="png")

function clip_im!(im::Array{<:AbstractFloat,2},minval::Float64,maxval::Float64)
    im[im.<minval] .= minval
    im[im.>maxval] .= maxval
end

function make_rgb()
    ibd1,ibd2,albedo,shadowmask = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5") do f
        println(keys(f["ScalarDatasets"]))
        λ = read_attribute(f,"smooth_wavelengths")
        println(λ[end])
        return (
                f["ScalarDatasets/IBD_789_1309"][:,:],
                f["ScalarDatasets/IBD_1658_2498"][:,:],
                f["VectorDatasets/SmoothSpectra_GNDTRU"][:,:,end],
                BitMatrix(f["ShadowMaps/lowsignal_shadows"][:,:])
            )
    end

    #println(size(ibd1),size(ibd2),size(albedo))
    red_upper = 0.94
    red_lower = 0.05
    green_upper = 0.97
    green_lower = 0.05
    blue_upper = 0.9999
    blue_lower = 0.05

    clip_im!(ibd1,quantile(vec(ibd1),red_lower),quantile(vec(ibd1),red_upper))
    clip_im!(ibd2,quantile(vec(ibd2),green_lower),quantile(vec(ibd2),green_upper))
    clip_im!(albedo,quantile(vec(albedo),blue_lower),quantile(vec(albedo),blue_upper))

    conv_amount = 7
    #c=[1,1,1,1,1]./5
    gaus(x) = (1/sqrt(2*pi))*exp((-1*x^2)./2)
    c = gaus.(range(-3,3,conv_amount))
    c = c./sum(c)
    extr = length(c) ÷ 2 + 1
    ibd1=conv(c,ibd1)[extr:end-extr+1,:]
    ibd2=conv(c,ibd2)[extr:end-extr+1,:]
    albedo=conv(c,albedo)[extr:end-extr+1,:]

    StatsBase.transform!(StatsBase.fit(UnitRangeTransform,ibd1),ibd1)
    StatsBase.transform!(StatsBase.fit(UnitRangeTransform,ibd2),ibd2)
    StatsBase.transform!(StatsBase.fit(UnitRangeTransform,albedo),albedo)

    println(size(ibd1),size(ibd2),size(albedo))
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

function save_anything()
    arr,shadowmask,λ = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5") do f
        return (
            f["VectorDatasets/SmoothSpectra_GNDTRU"][:,:,end],
            BitMatrix(f["ShadowMaps/lowsignal_shadows"][:,:]),
            read_attribute(f,"smooth_wavelengths")
            )
    end

    println(λ[end])

    arr[shadowmask] .= NaN

    f = Figure(backgroundcolor = :transparent)
    ax = Axis(f[1,1])
    hidedecorations!(ax)
    hidespines!(ax)
    image!(ax,arr,interpolate=false,nan_color=RGB(0.2,0.05,0),colorrange=(0,0.4))

    CairoMakie.save("G:/Shared drives/Zach Lunar-VISE/Research Presentations/LPSC24/2900um_Band_target.png",f,size=(1000,1000))

    f
end

#@time make_rgb()
@time save_anything()

