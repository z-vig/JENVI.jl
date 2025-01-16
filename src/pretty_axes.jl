function format_regular!(ax::Axis)::Nothing
    ax.xticks = 0:0.5:3
    ax.xticksize = 8
    ax.xminorticks = IntervalsBetween(5)
    ax.xminorticksvisible = true
    ax.xminorticksize = 5
    ax.xticklabelfont = :bold
    ax.xticklabelsize = 20
    ax.xgridvisible = false

    ax.yticks = 0:0.05:0.5
    ax.yminorticks = IntervalsBetween(5)
    ax.yminorticksvisible = true
    ax.yticksize = 8
    ax.yminorticksize = 5
    ax.yticklabelfont = :bold
    ax.yticklabelsize = 20
    ax.ygridvisible = false

    ax.xlabel = "λ (μm)"
    ax.xlabelfont = :bold
    ax.xlabelsize = 20
    ax.ylabel = "Reflectance"
    ax.ylabelfont = :bold
    ax.ylabelsize = 20

    return nothing
end

function format_continuum_removed!(ax::Axis)::Nothing
    ax.xticks = 0:0.5:3
    ax.xticksize = 8
    ax.xminorticks = IntervalsBetween(5)
    ax.xminorticksvisible = true
    ax.xminorticksize = 5
    ax.xticklabelfont = :bold
    ax.xticklabelsize = 20
    ax.xgridvisible = false

    ax.yticks = 0.85:0.05:1.1
    ax.yminorticks = IntervalsBetween(5)
    ax.yminorticksvisible = true
    ax.yticksize = 8
    ax.yminorticksize = 5
    ax.yticklabelfont = :bold
    ax.yticklabelsize = 20
    ax.ygridvisible = false

    ax.xlabel = "λ (μm)"
    ax.xlabelfont = :bold
    ax.xlabelsize = 20
    ax.ylabel = "Continuum-Removed Reflectance"
    ax.ylabelfont = :bold
    ax.ylabelsize = 20

    return nothing
end
