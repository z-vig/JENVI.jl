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

    function applymask(arr::Array{<:AbstractFloat,3},mask::Matrix{Int64})
        arr[Bool.(mask),:] .= NaN
        return arr
    end

    SpecData(name,array,shadowmask,λ) = new(name,applymask(array,shadowmask),shadowmask,λ)
end

struct MapData <: AbstractImageData
    name::String
    array::Matrix{Float64}
    shadowmask::BitMatrix
    λ::Vector{Float64}

    function applymask(arr::Matrix{<:AbstractFloat},mask::Matrix{Int64})
        arr[Bool.(mask)] .= NaN
        return arr
    end

    MapData(name,array,shadowmask,λ) = new(name,applymask(array,shadowmask),shadowmask,λ)
end

struct ObservationData <: AbstractImageData
    sun_azi :: Matrix{Float32}
    sun_zen :: Matrix{Float32}
    m3_azi :: Matrix{Float32}
    m3_zen :: Matrix{Float32}
    phase :: Matrix{Float32}
    sun_pathlength :: Matrix{Float32}
    m3_pathlength :: Matrix{Float32}
    facet_slope :: Matrix{Float32}
    facet_aspect :: Matrix{Float32}
    facet_angle :: Matrix{Float32}
    shadowmask :: Matrix{Int64}

    function adjust_facet_angle(facetang::Matrix{Float32})
        return (180/pi)*acos.(facetang)
    end

    ObservationData(sun_azi,sun_zen,m3_azi,m3_zen,phase,sun_pathlength,m3_pathlength,facet_slope,facet_aspect,facet_angle,shadowmask) = new(sun_azi,sun_zen,m3_azi,m3_zen,phase,sun_pathlength,m3_pathlength,facet_slope,facet_aspect,adjust_facet_angle(facet_angle),shadowmask)

end

struct LocationData <: AbstractImageData
    lat :: Matrix{Float32}
    long :: Matrix{Float32}
    elev :: Matrix{Float32}
    shadowmask :: Matrix{Int64}
end

mutable struct GUIModule{T<:AbstractImageData}
    figure::Figure
    axis::Axis
    data::Observable{T}
end

Base.@kwdef mutable struct PlotsAccounting
    plot_number::Int = 1
    pointspec_plots::Vector{Tuple{Axis,Lines}} = []
    image_scatters::Vector{Tuple{Axis,Scatter}} = []
    area_coordinates::Vector{Tuple{Int,Int}} = []
    area_scatters::Vector{Tuple{Axis,Scatter}} = []
    image_polygons::Vector{Tuple{Axis,Poly}} = []
    areaspec_plots::Vector{Tuple{Axis,Lines}} = []
    areastd_plots::Vector{Tuple{Axis,Band}} = []
    plotted_data::Vector{Vector{Float64}} = []
end