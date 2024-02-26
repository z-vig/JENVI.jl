using HDF5
using Interpolations
using JENVI
using LazySets

function doubleLine_removal(dataset::HDF5.File)
    """
    Following method presented in Henderson et al., 2023
    First, a rough continuum is removed using fixed points at 700, 1550 and 2600 nm
    Next, three points are chosen from the maxima of this spectrum at:
     + 650 - 1000 nm
     + 1350 - 1600 nm
     + 2000 - 2600 nm
    Finally, with these endpoints, the final continuum is calculated from the rfl values at these points on the original spectrum
    """
    
    image = dataset["VectorDatasets/SmoothSpectra_GNDTRU"][:,:,:]
    λ = read_attribute(dataset,"smooth_wavelengths")

    #Getting initial continuum line
    cont1_band_indices = [findλ(λ,i)[1] for i ∈ [700,1550,2600]]

    cont1_wvls = [findλ(λ,i)[2] for i ∈ [700,1550,2600]]
    cont1_bands = image[:,:,cont1_band_indices]

    function run_linearinterp1(pt)
        #Interpolating between convex hull points and applying to desired wavelengths
        ys = cont1_bands[pt...,:]
        lin_interp = linear_interpolation(cont1_wvls,ys,extrapolation_bc=Interpolations.Line())
        return lin_interp.(λ)
    end

    coord_arr = [(x,y) for x in 1:size(image,1),y in 1:size(image,2)]

    cont1_complete = run_linearinterp1.(coord_arr)

    cont1_complete = permutedims([cont1_complete[I][k] for k=eachindex(cont1_complete[1,1]),I=CartesianIndices(cont1_complete)],(2,3,1))

    cont1_rem = image./cont1_complete

    range1 = (650,1000)
    range2 = (1350,1600)
    range3 = (2000,2600)

    cont2_band_indices = zeros(Int,size(image,1),size(image,2),3)
    n = 1
    for (i,j) ∈ [range1,range2,range3]
        min_index = findλ(λ,i)[1]
        max_index = findλ(λ,j)[1]
        cont2_band_indices[:,:,n] .= getindex.(argmax(cont1_rem[:,:,range(min_index,max_index)],dims=3),3).+(min_index-1)
        n+=1
    end

    cont2_wvls = map(i->λ[cont2_band_indices[i[1],i[2],:]],coord_arr)

    function get_bands(pt)
        x = pt[1]
        y = pt[2]
        image[x,y,cont2_band_indices[x,y,:]]
    end

    cont2_bands = get_bands.(coord_arr)

    function run_linearinterp2(pt)
        #Interpolating between convex hull points and applying to desired wavelengths
        xs = cont2_wvls[pt...]
        ys = cont2_bands[pt...,:][1]
        lin_interp = linear_interpolation(xs,ys,extrapolation_bc=Interpolations.Line())
        return lin_interp.(λ)
    end

    cont2_complete = run_linearinterp2.(coord_arr)

    cont2_complete = permutedims([cont2_complete[I][k] for k=eachindex(cont2_complete[1,1]),I=CartesianIndices(cont2_complete)],(2,3,1))

    cont2_rem = image./cont2_complete

    try
        delete_object(dataset,"VectorDatasets/2pContRem_Smooth_GNDTRU")
    catch _
        println("Creating new continuum removed, smoothed and ground-truthed dataset...")
    end

    try
        delete_object(dataset,"VectorDatasets/2pContinuum")
    catch _
        println("Creating new continuum dataset...")
    end

    dataset["VectorDatasets/2pContRem_Smooth_GNDTRU"] = cont2_rem
    dataset["VectorDatasets/2pContinuum"] = cont2_complete
    
    return cont1_band_indices,cont1_rem,cont1_complete,cont2_band_indices,cont2_wvls,cont2_complete,cont2_rem

end