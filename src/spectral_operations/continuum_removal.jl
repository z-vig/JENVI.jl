using HDF5
using Interpolations
using LazySets
using GLMakie

"""
    double_line_removal(dataset,dataset_path)

Following method presented in Henderson et al., 2023
First, a rough continuum is removed using fixed points at 700, 1550 and 2600 nm
Next, three points are chosen from the maxima of this spectrum at:
 + 650 - 1000 nm
 + 1350 - 1600 nm
 + 2000 - 2600 nm
Finally, with these endpoints, the final continuum is calculated from the rfl values at these points on the original spectrum
"""
function double_line_removal(λ::Vector{<:AbstractFloat},spectrum::Vector{<:AbstractFloat})
    
    #Getting initial continuum line
    cont1_band_indices = [findλ(λ,i)[1] for i ∈ [700,1550,2600]]

    cont1_wvls = [findλ(λ,i)[2] for i ∈ [700,1550,2600]]
    cont1_spectrum_values = spectrum[cont1_band_indices]

    lin_interp = linear_interpolation(cont1_wvls,cont1_spectrum_values,extrapolation_bc=Interpolations.Line())

    cont1_complete = lin_interp(λ)

    cont1_rem = spectrum./cont1_complete

    # return cont1_complete,cont1_rem
    RANGE1 = (650,1000)
    RANGE2 = (1350,1600)
    RANGE3 = (2000,2600)

    # # cont2_band_indices = zeros(Int,size(image,1),size(image,2),3)
    cont2_band_indices = zeros(Int,3)
    n = 1
    for (i,j) ∈ [RANGE1,RANGE2,RANGE3]
        min_index = findλ(λ,i)[1]
        max_index = findλ(λ,j)[1]
        cont2_band_indices[n] = argmax(cont1_rem[range(min_index,max_index)])+(min_index-1)
        n+=1
    end
    @debug cont2_band_indices

    cont2_wvls = λ[cont2_band_indices]
    cont2_spectrum_values = spectrum[cont2_band_indices]

    lin_interp2 = linear_interpolation(cont2_wvls,cont2_spectrum_values,extrapolation_bc=Interpolations.Line())

    cont2_complete = lin_interp2(λ)

    cont2_rem = spectrum./cont2_complete

    return cont2_complete,cont2_rem
end

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
# f = Figure(); ax1 = Axis(f[1,1]); ax2 = Axis(f[1,2])
# continuum,removed = double_line_removal(λ,spec)

# lines!(ax1,λ,spec)
# lines!(ax1,λ,continuum)
# lines!(ax2,λ,removed)

# f