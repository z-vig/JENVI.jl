# bandshape_math.jl

"
    BandShapeParams{T1, T2}(
        λ::Vector{T1},
        y::Vector{T1},
        λi::T2,
        λf::T2
    ) where {T1<:AbstractFloat, T2<:Real}

Struct for storing band shape information for a particular absorption feature
in a single spectrum.

# Arguments
- `λ::Vector{T1}`: Wavelengths of the analyzed spectrum.
- `y::Vector{T1}`: Y-Values (e.g. Reflectance or Radiance) of spectrum.
- `λi::T2`: Shorter wavelength value of absorption feature.
- `λf::T2`: Longer wavelength value of absorption feature.

# Fields
- `λ::Vector{T1}`: Wavelengths of the analyzed spectrum.
- `y::Vector{T1}`: Y-Values (e.g. Reflectance or Radiance) of spectrum.
- `λi::T2`: Shorter wavelength value of absorption feature.
- `λf::T2`: Longer wavelength value of absorption feature.
- `idxi::Int`: Index of shorter wavelength.
- `idxf::Int`: Index of longer wavelength.
"
struct BandShapeParams{T1<:AbstractFloat, T2<:Real}
    λ::Vector{T1}
    y::Vector{T1}
    λi::T2
    λf::T2
    idxi::Int
    idxf::Int
    function BandShapeParams{T1, T2}(
        λ::Vector{T1},
        y::Vector{T1},
        λi::T2,
        λf::T2
    ) where {T1<:AbstractFloat, T2<:Real}
        idxi, λi = findλ(λ, λi)
        idxf, λf = findλ(λ, λf)
        new{T1, T2}(λ, y, λi, λf, idxi, idxf)
    end
end
BandShapeParams(
    λ::Vector{Float64},
    y::Vector{Float64},
    λi::Float64,
    λf::Float64
) = BandShapeParams{Float64, Float64}(λ, y, λi, λf)


"
    BandCenterResults()

Simple struct for storing the results of a band center analysis.

# Fields
- `poly_x`: Interpolation wavelengths used in the polynomial fit.
- `poly_y`: Fitted polynomial values before continuum removal.
- `bc`: Estimated band center position after continuum correction.
"
struct BandCenterResults
    poly_x::Vector{Float64}
    poly_y::Vector{Float64}
    bc::Float64
end

"
    fit_continuum(bsp::BandShapeParams)

Fits a straight line between the two ends of the band shape specified by `bsp`.

# Arguments
- `bsp::BandShapeParams`: Parameters defining band shape calculation.
"
function fit_continuum(bsp::BandShapeParams)
    yi = bsp.y[bsp.idxi]
    yf = bsp.y[bsp.idxf]
    m = (yf-yi)/(bsp.λf-bsp.λi)
    b = yi - m*bsp.λi
    return C(x) = m .* x .+ b
end

"
    banddepth(bsp::BandShapeParams)::Float64

Returns the depth of an absorption feature.

# Arguments
- `bsp::BandShapeParams`: BandShapeParams object for a particular absorption
feature.
"
function banddepth(
    bsp::BandShapeParams
)::Float64
    C = fit_continuum(bsp)
    bd = sum([C(bsp.λ[i]) - bsp.y[i] for i ∈ bsp.idxi:bsp.idxf])
    return bd
end
"
    banddepth(
        λ::Vector{T1},
        y::Vector{T1},
        λi::T2,
        λf::T2
    ) where {T1<:AbstractFloat, T2<:Real}

Returns the depth of an absorption feature.

# Arguments
- `λ::Vector{T1}`
- `y::Vector{T1}`
- `λi::T2`
- `λf::T2`
"
function banddepth(
    λ::Vector{T1},
    y::Vector{T1},
    λi::T2,
    λf::T2
)::Float64 where {T1<:AbstractFloat, T2<:Real}
    bsp = BandShapeParams(λ, y, λi, λf)
    bd = banddepth(bsp)
    return bd
end

"
    bandposition(bsp::BandShapeParams)

Find the minimum position of an absorption feature.

# Arguments
- `bsp::BandShapeParams`: BandShapeParams object describing feature of
interest.

# Returns
- `BandCenterResults`: A struct containing:
    - `poly_x`: Interpolation wavelengths used in the polynomial fit.
    - `poly_y`: Fitted polynomial values before continuum removal.
    - `bc`: Estimated band center position after continuum correction.
"
function bandposition(bsp::BandShapeParams)
    allidx = bsp.idxi:bsp.idxf
    
    localy = bsp.y[allidx]
    localλ = bsp.λ[allidx]
    
    p = Polynomials.fit(localλ, localy, 3)
    poly_x = range(bsp.λi, bsp.λf, 100)
    poly_y = p.(poly_x)
    C = fit_continuum(bsp)
    poly_y_corrected = poly_y .- C.(poly_x)
    bc = poly_x[argmin(poly_y_corrected)]

    results = BandCenterResults(poly_x, poly_y, bc)
    return results
end

"
    bandposition(
        λ::Vector{T1},
        y::Vector{T1},
        λi::T2,
        λ::T2f
    ) where {T1<:AbstractFloat, T2<:Real}

Find the minimum position of an absorption feature.

# Arguments
- `λ::Vector{T1}`: Vector of wavelengths.
- `y::Vector{T1}`: Corresponding spectral reflectance or radiance values.
- `λi::T2`: Lower bound of the wavelength range to consider.
- `λf::T2`: Upper bound of the wavelength range to consider.

# Returns
- `BandCenterResults`: A struct containing:
    - `poly_x`: Interpolation wavelengths used in the polynomial fit.
    - `poly_y`: Fitted polynomial values before continuum removal.
    - `bc`: Estimated band center position after continuum correction.
"
function bandposition(
    λ::Vector{T1},
    y::Vector{T1},
    λi::T2,
    λf::T2
) where {T1<:AbstractFloat, T2<:Real}
    bsp = BandShapeParams(λ, y, λi, λf) 
    results = bandposition(bsp)
    return results
end
