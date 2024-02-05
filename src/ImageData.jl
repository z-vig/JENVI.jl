#ImageData.jl
"""
Here we define the struct for loading in image data.
"""

using GLMakie

abstract type AbstractImageData end


struct SpecData <: AbstractImageData
    name::String
    array::Array{Float64,3}
    shadowmask::BitMatrix
    λ::Vector{Float64}

    function applymask(arr::Array{<:AbstractFloat,3},mask::BitMatrix)
        arr[mask,:] .= NaN
        return arr
    end

    SpecData(name,array,shadowmask,λ) = new(name,applymask(array,shadowmask),shadowmask,λ)
end

struct MapData <: AbstractImageData
    name::String
    array::Matrix{Float64}
    shadowmask::BitMatrix
    λ::Vector{Float64}

    function applymask(arr::Matrix{<:AbstractFloat},mask::BitMatrix)
        arr[mask] .= NaN
        return arr
    end

    MapData(name,array,shadowmask,λ) = new(name,applymask(array,shadowmask),shadowmask,λ)
end

mutable struct GUIModule{T<:AbstractImageData}
    figure::Figure
    axis::Axis
    data::Observable{T}
end

mutable struct PlotsAccounting
    plot_number::Int
    pointspec_plots::Vector{Tuple{Axis,Lines}}
    image_scatters::Vector{Tuple{Axis,Scatter}}
    area_coordinates::Vector{Tuple{Int,Int}}
    area_scatters::Vector{Tuple{Axis,Scatter}}
    image_polygons::Vector{Tuple{Axis,Poly}}
    areaspec_plots::Vector{Tuple{Axis,Lines}}
    areastd_plots::Vector{Tuple{Axis,Band}}
end