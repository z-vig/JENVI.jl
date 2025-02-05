module jenvi

import ArchGDAL as AG
using HDF5
using Polynomials
using CairoMakie
using GLMakie
using GLFW
using Gtk
using StatsBase
using PolygonOps
using LinearAlgebra
using Colors
using DSP
using Interpolations
using LazySets
using ColorVectorSpace
using Dates

GLMakie.activate!()

include("spectrum_visualizer_structs.jl")

include("utils.jl")
export norm_im,
       norm_im_controlled,
       findλ,
       img2h5,
       safe_add_to_h5,
       copy_spectral_axis!,
       mult_rgb,
       make3d

include("hdf5IO.jl")
export H5cube,
       H5rgb,
       H5raster,
       h52arr,
       export_spectra,
       export_image

include("pretty_axes.jl")
export format_regular!,
       format_continuum_removed!

include("image_visualizer.jl")
export image_visualizer

include("spectrum_visualizer.jl")
export spectrum_visualizer

include("roi_visualizer.jl")
export roi_visualizer

include("mixture_visualizer.jl")
export mixture_visualizer

include("bandshape_math.jl")
export BandShapeParams,
       banddepth,
       bandposition

include("bandshape_visualizer.jl")
export bandshape_visualizer

include("spectral_angle_map.jl")
export SAMEndmembers,
       SAM

include("spectral_operations/spectral_smoothing.jl")
export moving_avg

include("spectral_operations/continuum_removal.jl")
export double_line_removal

end #module