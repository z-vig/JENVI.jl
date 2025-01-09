module jenvi

import ArchGDAL as AG
using HDF5
using Polynomials
using GLMakie
using Gtk
using StatsBase
using PolygonOps
using LinearAlgebra

include("utils.jl")
export HDF5FileLocation,
       h52arr,
       findλ,
       img2h5,
       safe_add_to_h5

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

end #module