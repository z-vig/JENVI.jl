#use_gui.jl
using JENVI
using HDF5
using GLMakie
using Statistics


function get_arrays()

    h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps.hdf5")

    # all_data = Vector{Array{Float64,3}}(undef,length(keys(h5file)))
    all_data = Dict{String,Array{Float64,3}}()

    for i ∈ eachindex(keys(h5file))
        key = keys(h5file)[i]
        arr = read(h5file[key])
        if ndims(arr) < 3
            arr = reshape(arr,(size(arr)...,1))
        end
        all_data[key] = arr
    end

    close(h5file)
    #println([size(all_data[i]) for i in eachindex(all_data)])
    return all_data
end




function build_gui()

    datadict = get_arrays()

    rawλ::Vector{Float64} = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/wvl/wvl_data.txt"))]
    smoothλ::Vector{Float64} = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/wvl/smoothed_wvl_data.txt"))]

    @time figdict = init_fig()
    @time obsdict = init_obs(figdict,datadict,rawλ)
    @time reflectanceviewer(figdict,obsdict)
    @time histogramviewer(figdict,obsdict)
    @time spectralviewer(figdict,obsdict,datadict,rawλ,smoothλ)

    return nothing
end

@time build_gui()
GC.gc()

# @time figlist = init_fig()
# @time obsdict = init_obs(im,spec,λ,figlist)
# @time imfig,imax = reflectanceviewer(figlist,obsdict)
# histogramviewer(im,figlist,obsdict)
# spectralviewer(figlist,spec,λ,imax)

#fim,f = build_gui(im,spec,λ)