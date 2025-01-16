using HDF5

h5 = h5open("C:/SelenoSpecData/M3_data/gruit/region.hdf5")

h5open("C:/SelenoSpecData/M3_data/gruit/region_showrtwvls.hdf5","w") do f
    for group in keys(h5)
        for ds in keys(h5[group])
            name = "$group/$ds"
            if size(h5[name][:,:,:],3) == 83
                arr = h5[name][:,:,:]
                arr = arr[:,:,1:71]
                f[name] = arr
            end
        end
    end
end