using CairoMakie
using HDF5
CairoMakie.activate!(type="png")

function get_dat(spec)
    dat = open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/SavedGUIData/$(spec).txt") do f
        return readlines(f)
    end

    dat = [parse.(Float64,split(i,",")) for i in dat]

    
    return dat
end

function save_this(data,name::String)
    λ = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5") do f
        return read_attribute(f,"smooth_wavelengths")./1000
    end

    fig = Figure(backgroundcolor=:transparent,figsize=(500,600))
        ax = Axis(
            fig[1,1],
            xticks = 1:0.5:3,
            yticks = 0.85:0.05:1.05,
            xminorticksvisible = true,
            xminorticks = IntervalsBetween(5),
            xminorticksize= 6,
            xticksize = 8,
            xgridvisible=true,
            backgroundcolor = :transparent,
            xticklabelsize=20,xticklabelfont="Verdana",
            yticklabelsize=20,yticklabelfont="Verdana",
            limits = (minimum(λ),maximum(λ),0.85,1.05)
        )

    if ndims(data)>1
        for i in eachcol(data)
            lines!(ax,λ,i)
        end
    else
        for i in eachindex(data)
            lines!(ax,λ,data[i],label="$i")
        end
    end

    CairoMakie.save("G:/Shared drives/Zach Lunar-VISE/Research Presentations/LPSC24/spectra/$(name).svg",fig,size=(600,500))

    fig

end

@time d1 = get_dat("mare_spec")
@time d2 = get_dat("crater_spec")
@time d3 = get_dat("west_slope")
@time d4 = get_dat("on-off-dome")
@time d5 = get_dat("ol_spec_3")
@time d6 = get_dat("global1_ol")
@time d7 = get_dat("global2_ol")

d_dome_material = cat(d3[1],d4[2],d2[:]...,dims=2)
d_offdome_material = cat(d1[:]...,d4[1],dims=2)

# save_this(d_dome_material,"dome_materials")
# save_this(d_offdome_material,"offdome")
# save_this(d5,"olivine")