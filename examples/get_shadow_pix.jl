using HDF5
using ENVI
using GLMakie
using JENVI

function find_shadows(h5path)
    # envi_to_hdf5("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/175211/M3G20090208T175211_V03_OBS.IMG","C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/175211/M3G20090208T175211_V03_OBS.HDR","C:/Users/zvig/.julia/dev/JENVI.jl/Data/global1_obs.hdf5")
    h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/target_crop_coordinates.hdf5")
    coords = read(h5file["coords"])
    close(h5file)

    h5file = h5open("C:/Lunar_Imagery_Data/gruithuisen_m3target/rfl_020644.hdf5")
    println(size(h5file["raw/radiance"][1,1,:]))
    println(minimum(coords[:,1]):maximum(coords[:,1])," ",minimum(coords[:,2]):maximum(coords[:,2]))
    refarr = h5file["raw/radiance"][:,minimum(coords[:,1]):maximum(coords[:,1]),minimum(coords[:,2]):maximum(coords[:,2])]
    close(h5file)
    refarr = permutedims(refarr,(2,3,1))
    refarr = refarr[:,end:-1:1,9:end-1]

    h5file = h5open(h5path)
    arr = h5file["raw/radiance"][:,minimum(coords[:,1]):maximum(coords[:,1]),minimum(coords[:,2]):maximum(coords[:,2])]
    println(size(h5file["raw/radiance"][1,1,:]))
    close(h5file)

    arr = permutedims(arr,(2,3,1))
    arr = arr[:,end:-1:1,:]
    println(size(arr))

    f=Figure()
    ax1=Axis(f[1,1])
    ax2=Axis(f[1,2])
    ax3=Axis(f[1,3])

    i_arr = (180/pi)*acos.(arr[:,:,10])
    #i_arr = arr[:,:,8]

    sl = IntervalSlider(f[2,1],range=LinRange(minimum(i_arr),maximum(i_arr),1000),tellwidth=false)
    image!(ax1,i_arr,colorrange=sl.interval,interpolate=false)
    hist!(ax2,vec(i_arr))
    image!(ax3,refarr[:,:,1])
    display(GLMakie.Screen(),f)

    # h5save = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global1.hdf5","r+")
    # h5save["FacetAngle"] = i_arr
    # close(h5save)

    return nothing

end

find_shadows("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/obs_020644.hdf5")
GC.gc()