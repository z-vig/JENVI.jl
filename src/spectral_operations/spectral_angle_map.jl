"""
    SAMEndmembers()

Stores endmembers for use in `SAM` function

# Fields
- `data`: (NxM) Matrix of endmembers where N is number of endmembers and M is
the number of spectral bands
- `thresh`: Vector of endmember threshold values
- `names`: Vector of endmember names
"""
struct SAMEndmembers{T<:AbstractFloat}
    data::Matrix{T}
    thresh::Vector{T}
    names::Vector{String}
end

"""
    cosine_dist(M,I)

Compute the cosine distance between the target spectrum `M` and the reference
spectrum `I`
"""
function cosine_dist(
    M::Vector{<:AbstractFloat},
    I::Vector{<:AbstractFloat}
)::Float64
    ca = M⋅I/(norm(M)*norm(I))
    if ca>1
        return NaN
    else
        return rad2deg(acos(ca))
    end
end


"
Compute a Spectral Angle Map (SAM) between each pixel spectrum in a
hyperspectral image `arr` and a set of `endmembers`.

# Arguments
- `arr::Array{T,3}`: A 3D hyperspectral data cube with dimensions 
  (rows, columns, bands), where `T` is a subtype of `AbstractFloat`.
- `endmembers::SAMEndmembers`: A structure containing reference spectra 
  (endmembers), each of which is compared against every pixel spectrum.
- `classify::Bool=false`: If `true`, returns a classified 2D image where each
pixel is assigned the index of the closest matching endmember (based on a
spectral angle threshold); otherwise, returns the full 3D array of spectral
angles.

# Returns
- If `classify == false`, returns a 3D `Array{Float64,3}` of spectral angle
values with size `(rows, cols, n_endmembers)`, where each slice along the
third dimension corresponds to one endmember.
- If `classify == true`, returns a 2D `Array{Float64,2}` where each pixel
contains:
    - `n + 1`: Index (1-based) of the matching endmember (i.e., `argmin + 1`)
    if any angle is below `1.1` radians.
    - `1.0`: If all angles are greater than or equal to `1.1°` (i.e.,
    unclassified).
    - `NaN`: For any unexpected case (should not typically occur).

# Notes
- The spectral angle is computed using `cosine_dist`, which returns the angular 
  distance (in radians) between two spectra.
- The threshold value `1.1°` is used to determine match validity 
  during classification.

# Example
```julia
sam_cube = SAM(data_cube, endmembers)
classified_map = SAM(data_cube, endmembers; classify=true)
```
"
function SAM(
    arr::Array{T},
    endmembers::SAMEndmembers;
    classify::Bool = false
) where {T<:AbstractFloat}
    # Makes `sam` a 3D array of spectral angle values, with the third dimension
    # being SAM values for each endmember.
    sam = Array{Float64,3}(
        undef, size(arr, 1), size(arr, 2), size(endmembers.data, 1)
    )

    for (n, i) ∈ enumerate(eachrow(endmembers.data))
        spec_angle = map(CartesianIndices(axes(arr)[1:2])) do c
            x,y = Tuple(c)
            return cosine_dist(arr[x,y,:], Vector(i))
        end
        sam[:, :, n] .= spec_angle
    end

    if classify
        sam_classified = map(CartesianIndices(axes(sam)[1:2])) do i
            x,y=Tuple(i)
            if any(sam[x,y,:] .< 1.1)
                return float(argmin(sam[x,y,:]))+1
            elseif all(sam[x,y, :] .>= 1.1)
                return 1.0
            else
                return NaN
            end
        end
        return sam_classified
    else
        return sam
    end
end

"""
    SAM(h5loc,endmembers;classify=false)

Convenience method that loads a hyperspectral image from an HDF5 location and 
computes the Spectral Angle Map (SAM) relative to the given endmembers.

# Arguments
- `h5loc::T`: An HDF5 image location, typically pointing to a dataset on disk 
  that can be read into a `(rows, cols, bands)` array.
- `endmembers::SAMEndmembers`: Reference spectra for computing spectral angle.
- `classify::Bool=false`: Whether to return a classified map instead of raw 
  spectral angle values (see above).

# Returns
- Equivalent to calling `SAM(arr, endmembers; classify=...)` after loading the 
  hyperspectral data from the HDF5 location.
"""
function SAM(
    h5loc::T,
    endmembers::SAMEndmembers;
    classify::Bool=false
) where {T<:AbstractH5ImageLocation}
    arr, λ = h52arr(h5loc)
    SAM(arr, endmembers; classify)
end
