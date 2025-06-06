abstract type AbstractH5ImageLocation end

"
    H5cube(path,dat,bands)

Holds file path information for an HDF5 image cube

# Fields
- `path`: File path for the HDF5 file
- `data`: Internal path to the relevant data
- `lbl`: Internal path to band names attribute (e.g. wavelengths)
"
struct H5cube <: AbstractH5ImageLocation
    path::String
    data::String
    lbl::String
end

"
    H5rgb(path,red,green,blue,band_names)

Holds file path information for an HDF5 rgb image composite

# Fields
- `path`: File path for the HDF5 file
- `data`: Internal path to data
- `red`: Band number to use for the red band image
- `green`: Band number to use for the red band image
- `blue`: Band number to use for the red band image
- `lbl`: Internal path to the band names attribute for the image cube. `red`,
        `green` and `blue` fields will be used to pull the appropriate labels.
"
struct H5rgb <: AbstractH5ImageLocation
    path::String
    data::String
    red::Int
    green::Int
    blue::Int
    lbl::String
end

"
    H5raster(path,dat)

Holds file path information for a 1D HDF5 raster

# Fields
- `path`: File path to for the HDF5 file
- `data`: Internal path to 1D raster
- `lbl`: Internal path to raster name attribute
"
struct H5raster <: AbstractH5ImageLocation
    path::String
    data::String
    lbl::String
end

"
    h52arr(h5loc::AbstractH5FileLocation)

Returns HDF5 data from an AbstractH5FileLocation. Return type depends on the
type of `h5loc`.
"
function h52arr(h5loc::T) where {T<:AbstractH5ImageLocation}
    arr,lbls = h5open(h5loc.path) do f
        if typeof(h5loc) == H5cube || typeof(h5loc) == H5raster
            arr = read(f[h5loc.data])
            lbls = attrs(f)[h5loc.lbl]
        elseif typeof(h5loc) == H5rgb
            r = read(f[h5loc.data]); r = r[:,:,h5loc.red]
            g = read(f[h5loc.data]); g = g[:,:,h5loc.green]
            b = read(f[h5loc.data]); b = b[:,:,h5loc.blue]
            arr = cat(r,g,b,dims=3)
            lbls = attrs(f)[h5loc.lbl][[h5loc.red,h5loc.green,h5loc.blue]]
        end
        
        return arr,lbls
    end

    return arr,lbls
end

function export_spectra(
    ax::Axis,
    save_folder::String,
    sc::SpectraCollection;
    savename::Union{String,Nothing}=nothing
)
    CairoMakie.activate!()
    f = Figure(
        fonts = (; regular="Verdana",bold="Verdana Bold"),
        backgroundcolor=:transparent
    )
    save_axis = Axis(f[1,1],backgroundcolor=:transparent)
    format_regular!(save_axis)
    lbls,plot_data,λ = copy_spectral_axis!(ax,save_axis)

    names = [i.name for i in sc.spectra]

    if isnothing(savename)
        savestring = joinpath(
            save_folder,
            string("spectralplot_", Dates.format(now(),"yyyymmddTIIMMSS"))
        )
    else
        savestring = joinpath(save_folder,string("spectralplot_",savename))
    end

    CairoMakie.save("$savestring.svg",f)

    h5open("$(savestring)_data.hdf5","w") do f
        for (n,i) ∈ enumerate(lbls)
            f[i] = plot_data[n]
        end
    end
    GLMakie.activate!()
    return f
end

function export_image(
    ax::Axis,
    save_folder::String;
    savename::Union{String,Nothing}=nothing
)
    CairoMakie.activate!()
    f = Figure(
        fonts = (; regular="Verdana",bold="Verdana Bold"),
        backgroundcolor=:transparent
    )
    save_axis = Axis(f[1,1],backgroundcolor=:transparent,aspect=DataAspect())
    hidedecorations!(save_axis); hidespines!(save_axis)
    names,pts = copy_image_axis!(ax,save_axis)
    if isnothing(savename)
        savestring = joinpath(
            save_folder,
            string("image_",Dates.format(now(),"yyyymmddTIIMMSS"))
        )
    else
        savestring = joinpath(save_folder,string("image_",savename))
    end
    CairoMakie.save("$(savestring).png",f)

    open(joinpath(save_folder,string("$savestring","_pts.txt")),"w") do f
        println(f,"Color\tx\ty")
        for (name,pt) in zip(names,pts)
            println(f,"$name\t$(pt[1])\t$(pt[2])")
        end
    end
end