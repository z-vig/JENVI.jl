
function round_to_odd(x) :: Int
    r = round(Int, x)  # Round to the nearest integer
    return isodd(r) ? r : r + (sign(x - r) * 1)  # Adjust if even
end

"""
    remove_outliers(spectrum::Vector{<:AbstractFloat};threshold=2) :: Vector{Float64}

Removes outliers from a spectrum using the threshold method. The function returns the spectrum with the outliers removed.

# Arguments
- `spectrum::Vector{<:AbstractFloat}`: The input spectrum to be
"""
function remove_outliers(spectrum::Vector{<:AbstractFloat};threshold=2) :: Vector{Float64}
    μ,σ,idx = moving_avg(spectrum, box_size=round_to_odd(length(spectrum)*0.25), edge_handling = "extrapolate")
    zscore = (spectrum .- μ) ./ σ
    outlier_idx = abs.(zscore) .> threshold
    spectrum[outlier_idx] .= μ[outlier_idx]
    return spectrum
end

"""
    moving_avg(spectrum::Vector{<:AbstractFloat};box_size=5,edge_handling::String="extrapolate") :: Tuple{Vector{Float64},Vector{Float64},Vector{Int}}

Smooths the input spectrum using a moving average filter. The function returns the smoothed spectrum, the standard deviation of the smoothed spectrum, and the indices of the smoothed spectrum. The `box_size` parameter determines the size of the moving average filter. The `edge_handling` parameter determines how the edges of the spectrum are handled. The options are "mirror", "extrapolate", "fill_ends", and "cut_ends". The "mirror" option mirrors the spectrum at the edges, the "extrapolate" option extrapolates the spectrum at the edges, the "fill_ends" option fills the ends of the spectrum with the original data, and the "cut_ends" option cuts the ends of the spectrum.

# Arguments
- `spec::Vector{<:AbstractFloat}`: The input spectrum to be smoothed.
- `box_size::Int=5`: The size of the moving average filter.
- `edge_handling::String="extrapolate"`: The method used to handle the edges of the spectrum.
    - "mirror": Mirrors the spectrum at the edges.
    - "extrapolate": Extrapolates the spectrum at the edges.
    - "fill_ends": Fills the ends of the spectrum with the original data.
    - "cut_ends": Cuts the ends of the spectrum.
"""
function moving_avg(spectrum::Vector{<:AbstractFloat};box_size::Int=5,edge_handling::String="extrapolate",rm_outliers::Bool=false) :: Tuple{Vector{Float64},Vector{Float64},Vector{Int}}
    if iseven(box_size)
        println("box_size must be even!")
    end

    box = ones(box_size)
    endcap = box_size ÷ 2

    if rm_outliers
        spectrum = remove_outliers(spectrum,threshold=1.5)
    end

    if edge_handling == "mirror"
        spectrum = [reverse(spectrum[begin:begin+(box_size-1)]);spectrum;reverse(spectrum[end-(box_size-1):end])]
    elseif edge_handling == "extrapolate"
        #We are going to fix the number of points used for the linear extrapolation based on the lenght of the spectrum (10% of the spectrum length). Chaning the box size will simply effect how many points are extrapolated, not the number of points used for the extrapolation.
        fit_order = 1
        left_idx = 1:1+round(Int,length(spectrum)*0.1); right_idx = length(spectrum)-round(Int,length(spectrum)*0.1):length(spectrum)
        fit_left = Polynomials.fit(left_idx,spectrum[left_idx],fit_order); fit_right = Polynomials.fit(right_idx,spectrum[right_idx],fit_order)
        spectrum = [fit_left.([i for i in -box_size+1:0]);spectrum;fit_right.([i for i in length(spectrum):length(spectrum)+box_size-1])]
    end

    μ = conv(spectrum,box)[begin+endcap:end-endcap] ./ box_size
    μ² = conv(spectrum.^2,box)[begin+endcap:end-endcap] ./ box_size
    
    idx = 1:length(spectrum)

    #Removes convolution artifacts from the edges
    if edge_handling == "mirror" || edge_handling == "extrapolate"
        μ = μ[begin+box_size:end-box_size]
        μ² = μ²[begin+box_size:end-box_size]
        idx = idx[1:end-(2*box_size)]
    end

    σ = sqrt.(μ² .- μ.^2)

    if edge_handling == "fill_ends"
        μ[begin:begin+endcap] = spectrum[begin:begin+endcap]
        μ[end-endcap:end] = spectrum[end-endcap:end]
        σ[begin:begin+endcap] .= 0
        σ[end-endcap:end] .= 0
    elseif edge_handling == "cut_ends"
        μ = μ[begin+endcap:end-endcap]
        σ = σ[begin+endcap:end-endcap]
        idx = 1+endcap:length(spectrum)-endcap
    end

    return μ,σ,idx
end

function moving_avg(cube::Array{<:AbstractFloat,3},box_size::Int=5,edge_handling::String="extrapolate")
    ax = axes(cube)
    mvavg_res = map(CartesianIndices(ax[1:2])) do I
        x,y = Tuple(I)
        spec = cube[x,y,:]
        return moving_avg(spec,box_size=box_size,edge_handling=edge_handling)
    end
    μ,σ,idx = separate_tuple_matrix(mvavg_res) #Separate the matrix of tuples into three matrices

    return make3d(μ),make3d(σ),make3d(idx)
end


function separate_tuple_matrix(matrix::Matrix{<:Tuple{<:Vector{T1}, <:Vector{T1}, <:Vector{T2}}}) where {T1 <: Real, T2 <: Real}
    # Determine the size of the input matrix
    rows, cols = size(matrix)
    
    # Initialize three empty matrices to hold the separated vectors
    matrix1 = Matrix{Vector{Float32}}(undef, rows, cols)
    matrix2 = Matrix{Vector{Float32}}(undef, rows, cols)
    matrix3 = Matrix{Vector{Int}}(undef, rows, cols)
    
    # Iterate over the input matrix and populate the new matrices
    for i in 1:rows
        for j in 1:cols
            vector1, vector2, vector3 = matrix[i, j]
            matrix1[i, j] = vector1
            matrix2[i, j] = vector2
            matrix3[i, j] = vector3
        end
    end
    
    return matrix1, matrix2, matrix3
end

function make3d(im::Array{<:Vector{<:Real},2})
    """
    A function for turning a Matrix{Vector{Float64}} to an Array{Float64,3}
    """
    return permutedims([im[I][k] for k=eachindex(im[1,1]),I=CartesianIndices(im)],(2,3,1))
end

using HDF5
using GLMakie
using DSP
using Polynomials

arr,λ = h5open("C:/SelenoSpecData/M3_data/targeted/hdf5_files/new_mosaic.hdf5") do f
    return f["VectorDatasets/Reflectance"][:,:,:],attrs(f)["wavelengths"]
end

mypoint = [0,0]
while true
    x = rand(1:size(arr,1)); y = rand(1:size(arr,2))
    if isfinite(arr[x,y,1])
        mypoint[1] = x; mypoint[2] = y
        break
    end
end
mypoint = [290,249]
mypoint = [371,size(arr,2)-463]

#Testing code for smoothing an entire image cube
function test_image_cube()
    μ,σ,idx = moving_avg(arr)
    println(typeof(μ))
    println(size(smooth_arr))
end

#Testing code for outlier detection
function test_outlier_detection() :: Nothing
    f = Figure(); ax = Axis(f[1:10,1])
    s = Slider(f[end+2,:],range=0.1:0.01:3)
    Label(f[end+1,:],@lift(string("Threshold: ",$(s.value))),tellwidth=false,tellheight=false)

    clean_signal = @lift(remove_outliers(arr[mypoint...,:],threshold=$(s.value)))
    μ,σ,idx = moving_avg(arr[mypoint...,:],box_size=5,edge_handling="extrapolate",rm_outliers=true)
    
    lines!(ax,λ,arr[mypoint...,:],color=:black)
    lines!(ax,λ,clean_signal,color=:red)
    lines!(ax,λ,μ,color=:blue)
    display(GLMakie.Screen(),f)

    return nothing
end
# test_outlier_detection()

#Testing code that compares the different types of convolutional edge handling cases.
function test_edge_cases()

    f = Figure();ax = Axis(f[1,1],title=string("Reflectance at: ",mypoint)); ax1 = Axis(f[1,2]); ax2 = Axis(f[2,1]); ax3 = Axis(f[2,2]); ax4 = Axis(f[3,1]); ax5 = Axis(f[3,2]); ax6 = Axis(f[4,1]); ax7 = Axis(f[4,2])
    s = Slider(f[end+1,:],range=3:2:21)

    spec = arr[mypoint[1],mypoint[2],:]
    mvavg_obs1 = @lift(moving_avg(spec,box_size=$(s.value),edge_handling="mirror"))
    μ1,σ1,idx1 = @lift($mvavg_obs1[1]),@lift($mvavg_obs1[2]),@lift($mvavg_obs1[3])

    mvavg_obs2 = @lift(moving_avg(spec,box_size=$(s.value),edge_handling="extrapolate"))
    μ2,σ2,idx2 = @lift($mvavg_obs2[1]),@lift($mvavg_obs2[2]),@lift($mvavg_obs2[3])

    mvavg_obs3 = @lift(moving_avg(spec,box_size=$(s.value),edge_handling="fill_ends"))
    μ3,σ3,idx3 = @lift($mvavg_obs3[1]),@lift($mvavg_obs3[2]),@lift($mvavg_obs3[3])

    mvavg_obs4 = @lift(moving_avg(spec,box_size=$(s.value),edge_handling="cut_ends"))
    μ4,σ4,idx4 = @lift($mvavg_obs4[1]),@lift($mvavg_obs4[2]),@lift($mvavg_obs4[3])


    on(mvavg_obs1) do _
        reset_limits!(ax)
        reset_limits!(ax1)
        reset_limits!(ax2)
        reset_limits!(ax3)
        reset_limits!(ax4)
        reset_limits!(ax5)
        reset_limits!(ax6)
        reset_limits!(ax7)
    end

    lines!(ax,λ,spec)
    lines!(ax,λ,μ1)
    lines!(ax1,λ,σ1)
    ax.xlabel = "Wavelength (nm)"
    ax.ylabel = "Mirrored Edges"
    ax1.title = "σ"

    lines!(ax2,λ,spec)
    lines!(ax2,λ,μ2)
    lines!(ax3,λ,σ2)
    ax2.xlabel = "Wavelength (nm)"
    ax2.ylabel = "Extrapolated Edges"


    lines!(ax4,λ,spec)
    lines!(ax4,λ,μ3)
    lines!(ax5,λ,σ3)
    ax4.xlabel = "Wavelength (nm)"
    ax4.ylabel = "Filled Edges"


    # println(size(λ)," ",size(μ4[])," ",size(σ4[]))
    on(s.value) do _
        empty!(ax6);empty!(ax7)
        idx_temp = idx4[]
        mu_temp = μ4[]
        sig_temp = σ4[]
        lines!(ax6,λ,spec,color=:blue)
        lines!(ax6,λ[idx_temp],mu_temp,color=:orange)
        lines!(ax7,λ[idx_temp],sig_temp,color=:blue)
    end
    ax6.xlabel = "Wavelength (nm)"
    ax6.ylabel = "Cut Edges"
    f
end


# test_outlier_detection()