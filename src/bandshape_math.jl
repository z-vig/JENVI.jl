@kwdef struct BandShapeParams
    λ::Vector{<:AbstractFloat}
    y::Vector{<:AbstractFloat}
    λi::Real
    λf::Real
    idxi::Int = 0
    idxf::Int = 0
    function BandShapeParams(λ,y,λi,λf,idxi,idxf)
        idxi,λi = findλ(λ,λi)
        idxf,λf = findλ(λ,λf)
        new(λ,y,λi,λf,idxi,idxf)
    end
end

struct BandCenterResults
    poly_x::Vector{Float64}
    poly_y::Vector{Float64}
    bc::Float64
end

function fit_continuum(bsp::BandShapeParams)
    yi = bsp.y[bsp.idxi]; yf = bsp.y[bsp.idxf]
    m = (yf-yi)/(bsp.λf-bsp.λi)
    b = yi - m*bsp.λi
    return C(x) = m .* x .+ b
end

function banddepth(λ::Vector{<:AbstractFloat},y::Vector{<:AbstractFloat},λi::Real,λf::Real)
    
    bsp = BandShapeParams(λ=λ,y=y,λi=λi,λf=λf)
    C = fit_continuum(bsp)
    bd = sum([C(λ[i]) - y[i] for i ∈ bsp.idxi:bsp.idxf])
    return bd
end

function bandposition(λ,y,λi,λf)
    bsp = BandShapeParams(λ=λ,y=y,λi=λi,λf=λf)
    allidx = bsp.idxi:bsp.idxf
    localy = y[allidx]; localλ = λ[allidx]
    p = Polynomials.fit(localλ,localy,6)
    poly_x = range(λi,λf,100)
    poly_y = p.(poly_x)
    C = fit_continuum(bsp)
    poly_y_corrected = poly_y .- C.(poly_x)
    bc = poly_x[argmin(poly_y_corrected)]

    results = BandCenterResults(poly_x,poly_y,bc)
    return results
end

