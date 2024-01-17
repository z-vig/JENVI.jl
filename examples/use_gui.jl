#use_gui.jl
using JENVI
using HDF5
using GLMakie
using Statistics

smoothfile = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gd_region_smoothed.hdf5")
smoothim = read(smoothfile["gamma"])
close(smoothfile)

# impath = "C:/Users/zvig/.julia/dev/JENVI.jl/Data/gd_region_smoothed.hdf5"
specpath = "C:/Users/zvig/.julia/dev/JENVI.jl/Data/gd_region_2p_removed.hdf5"
impath = ask_file("./Data")
#specpath = ask_file("./Data")

imfile = h5open(impath)
im = read(imfile["gamma"])
close(imfile)

# shadowmask = mean(smoothim,dims=3)[:,:,1].<0.05
# im[shadowmask,:].=NaN
# println(size(vec(im[isnan.(im).==true])))

specfile = h5open(specpath)
spec = read(specfile["gamma"])
close(specfile)

λ = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/wvl/smoothed_wvl_data.txt"))]



figlist = init_fig()
obsdict = init_obs(im,spec,λ,figlist)
imfig,imax = imageviewer(figlist,obsdict)
histogramviewer(im,figlist,obsdict)
spectralviewer(spec,λ,imfig,imax)

#fim,f = build_gui(im,spec,λ)