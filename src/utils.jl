# utils.jl

using ColorSchemes
using Colors

function norm_im(arr::Matrix{<:AbstractFloat})
    real_arr = arr[isfinite.(arr)]
    return (arr .- minimum(real_arr)) ./ (maximum(real_arr) - minimum(real_arr))
end

function norm_im_controlled(arr::Matrix{<:AbstractFloat},lo::T,hi::T) where {T<:AbstractFloat}
    arr[arr.>hi] .= hi
    arr[arr.<lo] .= lo
    return (arr .- lo) ./ (hi - lo)
end


"""
    safe_add_to_h5(h5file_obj,name,data)

Add file to hdf5 file, but it will replace the file if there is already a file that exists of the same name.
"""
function safe_add_to_h5(h5file_obj::HDF5.File,name::String,data) 

    try
        h5file_obj[name] = data
    catch
        println("Replacing $(name)...")
        delete_object(h5file_obj,name)
        h5file_obj[name] = data
    end
    return nothing
end



"""
    findλ(λ.targetλ)

Given a list of wavelengths, `λ`, find the index of a `targetλ` and the actual wavelength closest to your target.
"""
function findλ(λ::Vector{T},targetλ::Real)::Tuple{Int,Float64} where {T<:AbstractFloat}
    idx = argmin(abs.(λ .- targetλ))
    return (idx,λ[idx])
end

function rgb2vec(rgb::RGBA)
    return vec([rgb.r,rgb.g,rgb.b,rgb.alpha])
end

function mult_rgb(x::RGBA,y::RGBA)
    mul = x ⊙ y
    mul_vec = rgb2vec(mul)
    mul_vec[mul_vec.>1] .= 1
    return RGBA(mul_vec...)
end

function copy_spectral_axis!(src::Axis,dst::Axis)::Tuple{Vector{String},Vector{Vector{Float32}},Vector{Vector{Float32}}}
    label_vec = Vector{String}(undef,0)
    plot_wavelengths = Vector{Vector{Float32}}(undef,0)
    plot_data = Vector{Vector{Float32}}(undef,0)
    
    for pl in src.scene.plots
        x = pl.args[1][]
        y = pl.args[2][]
        println(length(x)," ",length(y))
        lines!(dst,x,y,color=pl.color,linestyle=pl.linestyle,linewidth=pl.linewidth)
        println(pl.color)
        lbl = string(pl.label[])
        push!(label_vec,lbl)
        push!(plot_data,y)
        push!(plot_wavelengths,x)
    end
    return label_vec,plot_data,plot_wavelengths
end

function copy_image_axis!(src::Axis,dst::Axis)::Tuple{Vector{String},Vector{Tuple}}
    pt_list = Vector{Tuple}(undef,0)
    name_list = Vector{String}(undef,0)
    for pl in src.scene.plots
        if typeof(pl) <: Image
            imdata = src.scene.plots[1].args[1][]
            # println(any(isnan.(imdata)))
            image!(dst,imdata,interpolate=false)
        elseif typeof(pl) <: Scatter
            pt = (pl.args[1][],pl.args[2][])
            push!(pt_list,pt)
            push!(name_list,string(pl.color[]))
            scatter!(dst,pt,color=pl.color,strokecolor=pl.strokecolor,strokewidth=pl.strokewidth)
        else
            @error "There is an unrecognized plot component!"
        end
    end

    return name_list,pt_list
end

function get_mean_spectrum(spectra_data::Vector{SpectrumData})::Vector{Float32}
    N = length(spectra_data)
    μ = (1/N)*sum([i.data for i in spectra_data])
    return μ
end

function get_mean_xy(spectra_data::Vector{SpectrumData})::Tuple{Vector{Int},Vector{Int}}
    return ([i.xpixel for i in spectra_data],[i.ypixel for i in spectra_data])
end

function make3d(im::Array{Vector{Float64},2})
    """
    A function for turning a Matrix{Vector{Float64}} to an Array{Float64,3}
    """
    return permutedims([im[I][k] for k=eachindex(im[1,1]),I=CartesianIndices(im)],(2,3,1))
end

function _normalize_image(image::AbstractArray{<:Real})
    img_min = minimum(filter(isfinite, image))
    img_max = maximum(filter(isfinite, image))
    return (image .- img_min) ./ (img_max - img_min)
end

function _apply_colormap(image::Array{Float64}, cmap::ColorScheme)
    height, width = size(image)
    rgb_array = Array{RGBA{Float32}}(undef, height, width)

    for i in 1:height, j in 1:width
        if isfinite(image[i, j])
            color = get(cmap, image[i, j])
            if typeof(color) <: RGB
                rgb_array[i, j] = RGBA{Float32}(color, 1.)
            else
                rgb_array[i, j] = RGBA{Float32}(color)
            end
        else
            rgb_array[i, j] = RGBA{Float32}(0., 0., 0., 0.)
        end
    end

    rgba_image = zeros(Float32, height, width, 4)
    for i in 1:height, j in 1:width
            rgba_image[i, j, 1] = red(rgb_array[i, j])
            rgba_image[i, j, 2] = green(rgb_array[i, j])
            rgba_image[i, j, 3] = blue(rgb_array[i, j])
            rgba_image[i, j, 4] = alpha(rgb_array[i, j])
    end

    return rgba_image
end

# Method 1: from symbol (e.g., :viridis)
"
    image_to_rgb_array(
        image::AbstractArray{<:Real},
        colormap::Symbol
    )

Applies a colormap to a raster image and turns it into a 3D array where the
four indices in the 3rd axis represent the R, G and B channels plus alpha.

# Arguments
- `image::AbstractArray{<:Real}`: 2D Raster to be converted.
- `colormap::Symbol`: Name of the colormap to be applied.
"
function image_to_rgb_array(
    image::AbstractArray{<:Real}, 
    colormap::Symbol
)
    normalized = _normalize_image(image)
    cmap = getfield(ColorSchemes, colormap)
    return _apply_colormap(normalized, cmap)
end

# Method 2: from list of colors
"
    image_to_rgb_array(
        image::AbstractArray{<:Real},
        colors::AbstractVector{<:Colorant}
    )

Applies a colormap to a raster image and turns it into a 3D array where the
three dimensions represent the R, G and B channels.

# Arguments
- `image::AbstractArray{<:Real}`: 2D Raster to be converted.
- `colors::AbstractVector{<:Colorant}`: List of colors to use as a colormap.
"
function image_to_rgb_array(
    image::AbstractArray{<:Real}, 
    colors::AbstractVector
)
    colorants = all(isa.(colors, Colorant)) ? colors :
                all(isa.(colors, Symbol)) ? parse.(Colorant, string.(colors)) :
                error("colors must be a list of Colorants or Symbols")

    normalized = _normalize_image(image)
    cmap = ColorScheme(colorants)
    return _apply_colormap(normalized, cmap)
end