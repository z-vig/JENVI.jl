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