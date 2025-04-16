# explore_spectra.jl

import ..H5cube
import ..H5rgb
import ..image_visualizer
import ..spectrum_visualizer


internal_hdf5_paths = Dict(
    :rfl => "VectorDatasets/Reflectance",
    :rfl_pds => "VectorDatasets/PDSReflectance",
    :params => "ScalarDatasets/ParameterSuite",
    :params_pds => "ScalarDatasets/PDSParameterSuite"
)

# RGB bounds for global_new gruithuisen region:
# [(-0.28, 1.58), (0.01, 1.63), (0.09, 0.22)]

"
    explore_cube(
        h5path::String,
        disp::Symbol,
        cube::Union{Symbol, Nothing},
        rgb_bands::Union{Vecotr{Int}, Nothing}
    )

Explore a spectral cube in an ENVI-like environment.

# Arguments
- `h5path::String`: File path to HDF5 file.
- `disp::Symbol`: Dataset key for display data.
- `cube::Symbol`: Optional. Dataset key for spectral cube. If `nothing`,
                  the value will be set to the same as `disp`. Default is
                  `nothing`.
- `rgb_bands::Vecotr{Int}`: Optional. If passed, must be a length 3 vector
                            where the three values are the the R, G and B bands
                            to display, respectively. Default is `nothing`.
- `rgb_boundsVector{Tuple{T, T}}`: Optional. R, G amd B band color ranges as 
                                   tuples in a vector. Default is `nothing`
"
function explore_cube(
    h5path::String,
    disp::Symbol,
    cube::Union{Symbol,Nothing}=nothing;
    rgb_bands::Union{Vector{Int}, Nothing}=nothing,  # [6, 3, 2] for params
    rgb_bounds::Union{Vector{Tuple{T, T}}, Nothing} = nothing
) where {T<:AbstractFloat}

    if isnothing(cube)
        cube = disp
    end

    if !isnothing(rgb_bands)

        if length(rgb_bands) != 3
            throw("Incorrect number of RGB bands passed.")
        end

        dispimg = H5rgb(
            h5path, internal_hdf5_paths[disp], rgb_bands..., "wavelengths"
        )

    elseif isnothing(rgb_bands)
        dispimg = H5cube(h5path, internal_hdf5_paths[disp], "wavelengths")
    end

    cubeimg = H5cube(h5path, internal_hdf5_paths[cube], "wavelengths")

    f = image_visualizer(dispimg; band=2, flip_image=true, rgb_bounds)
    spectrum_visualizer(f, cubeimg; flip_image=true)
end
