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

# =============================================================================
# Including utilities, I/O functions and plotting formats
include("utils.jl")
include("hdf5IO.jl")
include("pretty_axes.jl")
export norm_im, norm_im_controlled, findλ, img2h5, safe_add_to_h5,
       copy_spectral_axis!, mult_rgb, make3d, H5cube, H5rgb, H5raster, h52arr,
       export_spectra, export_image, format_regular!, format_continuum_removed!
# =============================================================================


# =============================================================================
# Including all spectral operations
include("spectral_operations/bandshape_math.jl")
include("spectral_operations/spectral_smoothing.jl")
include("spectral_operations/continuum_removal.jl")
include("spectral_operations/spectral_angle_map.jl")
export moving_avg, SAMEndmembers, SAM, double_line_removal, BandShapeParams,
       banddepth, bandposition
# =============================================================================


# =============================================================================
# Including all visualizers
include("visualizers/spectrum_visualizer_structs.jl")
include("visualizers/image_visualizer.jl")
include("visualizers/spectrum_visualizer.jl")
include("visualizers/roi_visualizer.jl")
include("visualizers/mixture_visualizer.jl")
include("visualizers/mixture_visualizer.jl")
include("visualizers/bandshape_visualizer.jl")
export image_visualizer, spectrum_visualizer, roi_visualizer,
       mixture_visualizer, bandshape_visualizer
# =============================================================================

end #module