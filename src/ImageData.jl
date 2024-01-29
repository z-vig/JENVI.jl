#ImageData.jl
"""
Here we define the struct for loading in image data.
"""

using GLMakie

struct ImageData{T}
    name::String
    array::Array{T}
    shadowmask::BitMatrix
    λ::Vector{Float64}
end

mutable struct GUIModule{T}
    figure::Figure
    axis::Axis
    data::Dict{String,ImageData}
end

shadow_removal!(mod::GUIModule{Array{Float64,3}}) = @lift($(mod.data)[(mod.shadow_bits.==1),:] .= NaN)

shadow_removal!(mod::GUIModule{Matrix{Float64}}) = @lift($(mod.data)[(mod.shadow_bits.==1),:] .= NaN)