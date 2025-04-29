# explore_SMA.jl

import ..mixture_visualizer
import ..H5cube


"
    explore_sma(h5path::String, model_num::Int)

Explores the results of Spectral Mixture Analysis.

# Arguments
- `h5path::String`: Path to hdf5 file containing results.
- `model_num::Int`: Model number to analyze. See excel sheet.
"
function explore_sma(
    h5path::String,
    model_num::Int
)

    MODEL_ID = "SMA_00$model_num"

    h5loc1 = H5cube(
        h5path,
        "$MODEL_ID/fractions",
        "wavelengths"
    )

    h5loc2 = H5cube(
        h5path,
        "$MODEL_ID/residuals",
        "wavelengths"
    )

    band_names = h5open(h5path) do f
        return attrs(f[MODEL_ID])["endmember_names"]
    end

    f1 = image_visualizer(
        h5loc1, band=1, flip_image = true, markbadvals=true,
        axis_title=band_names
    )

    f2 = image_visualizer(
        h5loc2, band=1, flip_image=true, axis_title="Residuals"
    )

    mixture_visualizer(
        f1,
        h5path,
        MODEL_ID,
        :mix1,
        flip_image=true
    )

    mixture_visualizer(
        f2,
        h5path,
        MODEL_ID,
        :mix2,
        flip_image=true
    )


end