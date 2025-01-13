abstract type AbstractH5ImageLocation end

"""
    H5Cube(path,dat,bands)

Holds file path information for an HDF5 image cube

#Fields
- `path`: File path for the HDF5 file
- `data`: Internal path to the relevant data
- `lbl`: Internal path to band names attribute (e.g. wavelengths)
"""
struct H5cube <: AbstractH5ImageLocation
    path::String
    data::String
    lbl::String
end

"""
    H5rgb(path,red,green,blue,band_names)

Holds file path information for an HDF5 rgb image composite

#Fields
-`path`: File path for the HDF5 file
-`red`: Band number to use for the red band image
-`green`: Band number to use for the red band image
-`blue`: Band number to use for the red band image
-`lbll`: Internal path to the band names attribute for the image cube. `red`, `green` and `blue` fields will be used to pull the appropriate labels.
"""
struct H5rgb <: AbstractH5ImageLocation
    path::String
    data::String
    red::Int
    green::Int
    blue::Int
    lbl::String
end

"""
    H5raster(path,dat)

Holds file path information for a 1D HDF5 raster

#Fields
-`path`: File path to for the HDF5 file
-`data`: Internal path to 1D raster
-`lbl`: Internal path to raster name attribute
"""
struct H5raster <: AbstractH5ImageLocation
    path::String
    data::String
    lbl::String
end

"""
    h52arr(h5loc::AbstractH5FileLocation)

Returns HDF5 data from an AbstractH5FileLocation. Return type depends on the type of h5loc.
"""
function h52arr(h5loc::T) where {T<:AbstractH5ImageLocation}
    arr,lbls = h5open(h5loc.path) do f
        if typeof(h5loc) == H5cube || typeof(h5loc) == H5raster
            arr = read(f[h5loc.data])
            lbls = attrs(f)[h5loc.lbl]
        elseif typeof(h5loc) == H5rgb
            r = read(f[h5loc.data]); r = r[:,:,h5loc.red]
            g = read(f[h5loc.data]); g = g[:,:,h5loc.green]
            b = read(f[h5loc.data]); b = b[:,:,h5loc.blue]
            arr = RGBA.(norm_im(r),norm_im(g),norm_im(b))
            arr[isnan.(arr)] .= RGBA(0.0,0.0,0.0,0.0)
            lbls = attrs(f)[h5loc.lbl][[h5loc.red,h5loc.green,h5loc.blue]]
        end
        
        return arr,lbls
    end

    return arr,lbls
end