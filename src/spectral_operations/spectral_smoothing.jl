function moving_avg(spectrum::Vector{<:AbstractFloat};box_size=5,edge_handling::String="extrapolate")
    if iseven(box_size)
        println("box_size must be even!")
    end

    box = ones(box_size)
    endcap = box_size ÷ 2

    if edge_handling == "mirror"
        spectrum = [reverse(spectrum[begin:begin+(box_size-1)]);spectrum;reverse(spectrum[end-(box_size-1):end])]
    elseif edge_handling == "extrapolate"
        #We are going to fix the number of points used for the linear extrapolation based on the lenght of the spectrum (10% of the spectrum length). Chaning the box size will simply effect how many points are extrapolated, not the number of points used for the extrapolation.
        fit_order = 1
        left_idx = 1:1+round(Int,length(spectrum)*0.1); right_idx = length(spectrum)-round(Int,length(spectrum)*0.1):length(spectrum)
        fit_left = fit(left_idx,spectrum[left_idx],fit_order); fit_right = fit(right_idx,spectrum[right_idx],fit_order)
        spectrum = [fit_left.([i for i in -box_size+1:0]);spectrum;fit_right.([i for i in length(spectrum):length(spectrum)+box_size-1])]
    end

    μ = conv(spectrum,box)[begin+endcap:end-endcap] ./ box_size
    μ² = conv(spectrum.^2,box)[begin+endcap:end-endcap] ./ box_size

    #Removes convolution artifacts from the edges
    if edge_handling == "mirror" || edge_handling == "extrapolate"
        μ = μ[begin+box_size:end-box_size]
        μ² = μ²[begin+box_size:end-box_size]
    end

    σ = sqrt.(μ² .- μ.^2)

    idx = 1:length(spectrum)

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

using HDF5
using GLMakie
using DSP
using Polynomials

arr,λ = h5open("C:/SelenoSpecData/M3_data/gruit/region.hdf5") do f
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

#290,249
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