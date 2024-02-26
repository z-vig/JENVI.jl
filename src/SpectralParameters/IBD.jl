# SPDX-License-Identifier: MIT
using HDF5
using JENVI

"""
    IBD_map(image::Array{<:AbstractFloat,3},continuum::Array{<:AbstractFloat,3},λvec::Vector{Float64},λ₁::Real,λ₂::Real)

TBW
"""

function IBD_map(dataset::HDF5.File,λ₁::Real,λ₂::Real)

    image = dataset["VectorDatasets/RawSpectra"][:,:,:]
    continuum = dataset["VectorDatasets/2pContinuum"][:,:,:]
    λvec = read_attribute(dataset,"smooth_wavelengths")

    min_λindex = findλ(λvec,λ₁)[1]
    max_λindex = findλ(λvec,λ₂)[1]
    λindices = min_λindex:1:max_λindex

    R = image[:,:,λindices]
    Rc = continuum[:,:,λindices]

    IBDmap = sum((1 .- (R ./ Rc)),dims=3)
    
    try
        delete_object(dataset,"ScalarDatasets/IBD_$(round(Int,λ₁))_$(round(Int,λ₂))")
    catch _
        println("Creating new IBD dataset...")
    end

    dataset["ScalarDatasets/IBD_$(round(Int,λ₁))_$(round(Int,λ₂))"] = IBDmap[:,:,1]

    return IBDmap

end