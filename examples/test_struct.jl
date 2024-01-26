using JENVI
using GLMakie
using HDF5

function run_gui()
    f = Figure()
    h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps.hdf5")
    data = read(h5file["SmoothSpectra"])
    close(h5file)


    mod1 = GUIModule{Array{Float64,3}}(Figure(),Observable{Array{Float64,3}}(data))

    band_value = band_selector!(mod1,(2,1))
    band_image::Observable{Matrix{Float64}} = @lift($(mod1.data)[:,:,$band_value])

    mod2 = GUIModule{Matrix{Float64}}(Figure(),band_image)

    hist_interval,imstretch,bin_edges,bin_colors = histogram_selector!(mod2,(2,1))
    
    axrfl = Axis(mod1.figure[1,1])
    axhist = Axis(mod2.figure[1,1])

    image!(axrfl,band_image,colorrange=imstretch)
    hist!(axhist,@lift(vec($(mod2.data))),bin_edges,bin_colors)


    display(GLMakie.Screen(),mod1.figure)
    display(GLMakie.Screen(),mod2.figure)

end

@time run_gui()
GC.gc()
