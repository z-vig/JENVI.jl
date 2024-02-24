using JENVI

initialize_hdf5(
    ("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_loc.img","C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_loc.hdr"),
    ("C:/Lunar_Imagery_Data/gruithuisen_m3target/020644/m3t20090418t020644_v01_rfl.img","C:/Lunar_Imagery_Data/gruithuisen_m3target/020644/m3t20090418t020644_v01_rfl.hdr"),
    ("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_obs.img","C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/020644/m3t20090418t020644_v03_obs.hdr"),
    [318.7,320,35.8,37.3],
    "C:/Users/zvig/.julia/dev/JENVI.jl/Data/testdata.hdf5"
)