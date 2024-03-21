using CairoMakie

function save_myfig(f::Figure,path::String)
    CairoMakie.save(path,f,size=(1000,1000))
end