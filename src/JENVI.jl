module JENVI

export ask_file,
       build_gui,
       reflectanceviewer,
       mapviewer,
       histogramviewer,
       spectralviewer,
       init_fig,
       init_obs,
       GUIModule,
       shadow_removal!,
       band_selector!,
       histogram_selector!,
       menu_selector!,
       activate_spectral_grab

include("JenviGUI.jl")
using .JenviGUI

include("GUI_modules/Observables.jl")
include("GUI_modules/Interactions.jl")

end