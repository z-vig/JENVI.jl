"""
    SAMEndmembers()

Stores endmembers for use in `SAM` function

#Fields
- `data`: (NxM) Matrix of endmembers where N is number of endmembers and M is the number of spectral bands
- `thresh`: Vector of endmember threshold values
- `names`: Vector of endmember names
"""
struct SAMEndmembers
    data::Matrix{<:AbstractFloat}
    thresh::Vector{Float16}
    names::Vector{String}
end

"""
    cosine_dist(M,I)

Compute the cosine distance between the target spectrum `M` and the reference spectrum `I`
"""
function cosine_dist(M::Vector{<:AbstractFloat},I::Vector{<:AbstractFloat})::Float64
    ca = M⋅I/(norm(M)*norm(I))
    if ca>1
        return NaN
    else
        return rad2deg(acos(ca))
    end
end

"""
    SAM(h5loc,endmembers;classify=false)

Make a spectral angle map of `h5loc` using `endmembers`. If `classify` is true, returns an encoded matrix based on threshold values.
"""
function SAM(h5loc::HDF5FileLocation,endmembers::SAMEndmembers; classify::Bool=false)
    arr,λ = h52arr(h5loc)

    #Makes `sam` a 3D array of spectral angle values, with the third dimension being SAM values for each endmember.
    sam = Array{Float64,3}(undef,size(arr,1),size(arr,2),size(endmembers.data,1))
    for (n,i) ∈ enumerate(eachrow(endmembers.data))
        spec_angle = map(CartesianIndices(axes(arr)[1:2])) do c
            x,y = Tuple(c)
            return cosine_dist(arr[x,y,:],Vector(i))
        end
        sam[:,:,n] .= spec_angle
    end

    if classify
        sam_classified = map(CartesianIndices(axes(sam)[1:2])) do i
            x,y=Tuple(i)
            if any(sam[x,y,:] .< 1.1)
                return float(argmin(sam[x,y,:]))+1
            elseif all(sam[x,y,:] .>= 1.1)
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
