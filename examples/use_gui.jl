#use_gui.jl
using JENVI
using HDF5
using GLMakie

impath = "C:/Users/zvig/.julia/dev/JENVI.jl/Data/gd_region_smoothed.hdf5"
specpath = "C:/Users/zvig/.julia/dev/JENVI.jl/Data/gd_region_2p_removed.hdf5"
# impath = ask_file("./Data")
# specpath = ask_file("./Data")

imfile = h5open(impath)
im = read(imfile["gamma"])
close(imfile)

specfile = h5open(specpath)
spec = read(specfile["gamma"])
close(specfile)

λ = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/wvl/smoothed_wvl_data.txt"))]



figlist = init_fig()
obsdict = init_obs(im,spec,λ,figlist)
imageviewer(figlist,obsdict)
histogramviewer(im,figlist,obsdict)

#fim,f = build_gui(im,spec,λ)