function moving_avg(spectrum::Vector{<:AbstractFloat};box_size=5)
    if iseven(box_size)
        println("box_size must be even!")
    end

    box = ones(box_size)
    endcap = box_size ÷ 2
    μ = conv(spectrum,box)[begin+endcap:end-endcap] ./ box_size
    μ² = conv(spectrum.^2,box)[begin+endcap:end-endcap] ./ box_size

    σ = sqrt.(μ² .- μ.^2)
    
    μ[begin:begin+endcap] = spectrum[begin:begin+endcap]
    μ[end-endcap:end] = spectrum[end-endcap:end]

    σ[begin:begin+endcap] .= 0
    σ[end-endcap:end] .= 0
    return μ,σ
end

# using HDF5
# using GLMakie

# arr,λ = h5open("C:/SelenoSpecData/M3_data/gruit/region.hdf5") do f
#     return f["VectorDatasets/Reflectance"][:,:,:],attrs(f)["wavelengths"]
# end

# mypoint = [0,0]
# while true
#     x = rand(1:size(arr,1)); y = rand(1:size(arr,2))
#     if isfinite(arr[x,y,1])
#         mypoint[1] = x; mypoint[2] = y
#         break
#     end
# end

# spec = arr[mypoint[1],mypoint[2],:]
# μ,σ = moving_avg(spec)

# #290,249
# f = Figure();ax = Axis(f[1,1],title=string(mypoint)); ax1 = Axis(f[1,2])
# lines!(ax,λ,spec)
# lines!(ax,λ,μ)
# lines!(ax1,λ,σ)
# f