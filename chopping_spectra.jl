using HDF5

h5 = h5open("C:/SelenoSpecData/M3_data/targeted/hdf5_files/new_mosaic.hdf5")

h5open("C:/SelenoSpecData/M3_data/targeted/mosaic_showrtwvls.hdf5","w") do f
    for group in keys(h5)
        for ds in keys(h5[group])
            name = "$group/$ds"
            if size(h5[name][:,:,:],3) == 247
                arr = h5[name][:,:,:]
                arr = arr[:,:,1:199]
                f[name] = arr
            end
        end
    end

    attrs(f)["wavelengths"] = attrs(h5)["wavelengths"][1:199]
end