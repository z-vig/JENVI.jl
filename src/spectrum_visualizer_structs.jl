@kwdef mutable struct SpectralViewerLayout
    parent_figure::Figure
    spectrumgrid::GridLayout = parent_figure[1,1] = GridLayout()
    buttongrid::GridLayout = parent_figure[2,1] = GridLayout()
    legendgrid::GridLayout = parent_figure[1,2] = GridLayout()
end

abstract type AbstractSpectrum end

struct SpectrumData <: AbstractSpectrum
    λ::Vector{<:AbstractFloat}
    data::Observable{Vector{<:AbstractFloat}}
    name::String
    color::RGB
    plot::Plot
    xpixel::Int
    ypixel::Int
    legend_entry::LineElement
end

struct MeanSpectrum <: AbstractSpectrum
    λ::Vector{<:AbstractFloat}
    data::Observable{Vector{Vector{<:AbstractFloat}}}
    name::String
    color::RGB
    xpixels::Observable{Vector{Int}}
    ypixels::Observable{Vector{Int}}
    legend_entry::LineElement
end

@kwdef mutable struct SpectraSearch
    cube_size::Tuple{Int,Int,Int}
    active::Observable{Bool} = Observable(false)
    averaging::Observable{Bool} = Observable(false)
    cursor_tracker::Observable{GLMakie.Point{2,Float32}} = Observable{GLMakie.Point{2,Float32}}((0,0))
    selected_tracker::Observable{GLMakie.Point{2,Int}} = Observable{GLMakie.Point{2,Int}}((0,0))
    tracker_lines::Vector{Plot} = Vector{Plot}(undef,0)
    current_spectrum::Vector{Float32} = Vector{Float32}(undef,cube_size[3])
    current_plot::Vector{Plot} = Vector{Plot}(undef,0)
end

@kwdef mutable struct SpectraCollection
    cube_size::Tuple{Int,Int,Int}
    active::Observable{Bool} = Observable(false)
    averaging::Observable{Bool} = Observable(false)
    collect_number::Observable{Int} = Observable(0)
    temp_mean_collection::Observable{Vector{SpectrumData}} = Observable(Vector{SpectrumData}(undef,0))
    spectra::Vector{<:AbstractSpectrum} = Vector{Union{SpectrumData,MeanSpectrum}}(undef,0)
    custom_name::Observable{Bool} = Observable(true)
end