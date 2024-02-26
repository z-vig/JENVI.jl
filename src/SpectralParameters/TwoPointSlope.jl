# SPDX-License-Identifier: MIT
using HDF5
using JENVI

"""
    slopemap(image::Array{<:AbstractFloat,3},λ::Vector{Float64},λmin::Float64,λmax::Float64)

TBW
"""
function slope_map(dataset::HDF5.File,λmin::Float64,λmax::Float64)

    image = dataset["VectorDatasets/SmoothSpectra_GNDTRU"]
    λ = read_attribute(dataset,"smooth_wavelengths")
    
    min_index = findλ(λ,λmin)[1]
    max_index = findλ(λ,λmax)[1]

    slope_map = Array{Float64}(undef,(size(image)[1:2]...,1))

    slope_map[:,:,1] .= (image[:,:,max_index] .- image[:,:,min_index]) ./ (max_index-min_index)

    try
        delete_object(dataset,"ScalarDatasets/slope_map_$(round(Int,λmin))_$(round(Int,λmax))")
    catch _
        println("Creating new slope map dataset...")
    end

    dataset["ScalarDatasets/slopemap_$(round(Int,λmin))_$(round(Int,λmax))"] = slope_map[:,:,1]

    return slope_map
end