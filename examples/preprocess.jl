using JENVI
using HDF5

"""
Here we define a pipeline for going from a downloaded envi file pair from the PDS to a processesed HDF5 dataset for image visualization, all in native Julia.

In general, the file structure for the hdf5 dataset is:

"""

#Puts location backplane, observation backplane and raw reflectance data into the dataset

# initialize_hdf5(
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_loc.img","C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_loc.hdr"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3target/020644/m3t20090418t020644_v01_rfl.img","C:/Lunar_Imagery_Data/gruithuisen_m3target/020644/m3t20090418t020644_v01_rfl.hdr"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_obs.img","C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_obs.hdr"),
#     "C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_rdn.hdr",
#     [35.8,37.3,318.7,320],
#     "C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_targeted.hdf5"
# )

# initialize_hdf5(
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020848/m3t20090418t020848_v03_loc.img","C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020848/m3t20090418t020848_v03_loc.hdr"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3target/020848/m3t20090418t020848_v01_rfl.img","C:/Lunar_Imagery_Data/gruithuisen_m3target/020848/m3t20090418t020848_v01_rfl.hdr"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020848/m3t20090418t020848_v03_obs.img","C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020848/m3t20090418t020848_v03_obs.hdr"),
#     "C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020848/m3t20090418t020848_v03_rdn.hdr",
#     [35.8,37.3,318.678,320],
#     "C:/Users/zvig/.julia/dev/JENVI.jl/Data/northwest_targeted.hdf5"
# )

# combine_hdf5(h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_targeted.hdf5"),h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/northwest_targeted.hdf5"),"C:/Users/zvig/.julia/dev/JENVI.jl/Data/all_targeted.hdf5")

# initialize_hdf5(
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/175211/M3G20090208T175211_V03_LOC.IMG","C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/175211/M3G20090208T175211_V03_LOC.HDR"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3global/175211/M3G20090208T175211_V01_RFL.IMG","C:/Lunar_Imagery_Data/gruithuisen_m3global/175211/M3G20090208T175211_V01_RFL.HDR"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/175211/M3G20090208T175211_V03_OBS.IMG","C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/175211/M3G20090208T175211_V03_OBS.HDR"),
#     "C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/175211/M3G20090208T175211_V03_RDN.HDR",
#     [35.8,37.3,317.0,319.8],
#     "C:/Users/zvig/.julia/dev/JENVI.jl/Data/global1.hdf5",
#     dataset_type="global"
# )

# initialize_hdf5(
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/194335/M3G20090208T194335_V03_LOC.IMG","C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/194335/M3G20090208T194335_V03_LOC.HDR"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3global/194335/M3G20090208T194335_V01_RFL.IMG","C:/Lunar_Imagery_Data/gruithuisen_m3global/194335/M3G20090208T194335_V01_RFL.HDR"),
#     ("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/194335/M3G20090208T194335_V03_OBS.IMG","C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/194335/M3G20090208T194335_V03_OBS.HDR"),
#     "C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/194335/M3G20090208T194335_V03_RDN.HDR",
#     [35.8,37.3,318.6,319.8],
#     "C:/Users/zvig/.julia/dev/JENVI.jl/Data/global2.hdf5",
#     dataset_type="global"
# )

function preprocess(gnd_tru_path::String,h5filepath::String,dataset_type::String)

    h5open(h5filepath,"r+") do h5file
        println("Applying Ground Truth Correction...")
        @time apply_gnd_tru(gnd_tru_path,h5file,dataset_type)

        println("Smoothing Spectral Domain...")
        @time movingavg(h5file,9,fill_ends=true)

        println("Removing 2-point continuum...")
        @time doubleLine_removal(h5file)

    #     println("Finding Shadows...")

    #     try
    #         create_group(h5file,"ShadowMaps")
    #     catch _
    #         println("Group already exists...")
    #     end

    #     @time facet_shadowmap(h5file)
    #     @time lowsignal_shadowmap(h5file)
    end

    # h5open(h5filepath,"r") do h5file
    #     display_h5file(h5file)
    # end

    return nothing
end

function spectral_parameters(h5filepath::String)

    h5open(h5filepath,"r+") do h5file

        println("Making IBD1000 map...")
        i1_min = 789
        i1_max = i1_min + 20*26
        @time IBD_map(h5file,i1_min,i1_max)

        println("Making IBD2000 map...")
        i2_min = 1658
        i2_max = i2_min + 40*21
        @time IBD_map(h5file,i2_min,i2_max)

        h5file["ScalarDatasets/band_ratio"] = h5file["ScalarDatasets/IBD_789_1309"][:,:]./h5file["ScalarDatasets/IBD_1658_2498"][:,:]

        println("Making 1μm Band Center Map...")
        λ_range = (650.,1350.)
        @time bandcenter_map(h5file,λ_range,fit_type="Spline")
        @time bandcenter_map(h5file,λ_range,fit_type="Polynomial")

        println("Making visible slope map...")
        @time slope_map(h5file,500.,1000.)

        println("Making SWIR slope map...")
        @time slope_map(h5file,2000.,2600.)
    end

    h5open(h5filepath,"r") do h5file
        display_h5file(h5file)
    end

    return nothing
end

@time preprocess("C:/Lunar_Imagery_Data/M3_data/pds_data/L2_Data/L2_target/calib/M3T20111117_RFL_GRND_TRU_1.TAB","C:/Lunar_Imagery_Data/M3_data/hdf5_files/target_corrected.hdf5","targeted")
@time spectral_parameters("C:/Lunar_Imagery_Data/M3_data/hdf5_files/target_corrected.hdf5")

# @time preprocess("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/gnd_tru1.tab","C:/Users/zvig/.julia/dev/JENVI.jl/Data/global1.hdf5","global")
# @time spectral_parameters("C:/Users/zvig/.julia/dev/JENVI.jl/Data/global1.hdf5")

# @time preprocess("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/gnd_tru1.tab","C:/Users/zvig/.julia/dev/JENVI.jl/Data/global2.hdf5","global")
# @time spectral_parameters("C:/Users/zvig/.julia/dev/JENVI.jl/Data/global2.hdf5")

GC.gc()

#display_h5file("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5")




