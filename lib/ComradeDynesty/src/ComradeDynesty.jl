module ComradeDynesty

using Comrade
using Dynesty

using AbstractMCMC
using TypedTables
using Reexport
using Random

@reexport using Dynesty


Comrade.samplertype(::Type{<:NestedSampler}) = Comrade.IsCube()
Comrade.samplertype(::Type{<:DynamicNestedSampler}) = Comrade.IsCube()

"""
    AbstractMCMC.sample(post::Comrade.Posterior, smplr::Dynesty.NestedSampler, args...; kwargs...)
    AbstractMCMC.sample(post::Comrade.Posterior, smplr::Dynesty.DynamicNestedSampler, args...; kwargs...)

Sample the posterior `post` using `Dynesty.jl` `NestedSampler/DynamicNestedSampler` sampler.
The `args/kwargs`
are forwarded to `Dynesty` for more information see its [docs](https://github.com/ptiede/Dynesty.jl)

This returns a tuple where the first element are the weighted samples from dynesty in a TypedTable.
The second element includes additional information about the samples, like the log-likelihood,
evidence, evidence error, and the sample weights. The final element of the tuple is the original
dynesty output file.

To create equally weighted samples the user can use
```julia
using StatsBase
chain, stats = sample(post, NestedSampler(dimension(post), 1000))
equal_weighted_chain = sample(chain, Weights(stats.weights), 10_000)
```
"""
function AbstractMCMC.sample(::Random.AbstractRNG, post::Comrade.TransformedPosterior,
                             sampler::Union{NestedSampler, DynamicNestedSampler}
                             ; init_params=nothing,
                             kwargs...)
    ℓ = logdensityof(post)
    kw = delete!(Dict(kwargs), :init_params)
    res = dysample(ℓ, identity, sampler; kw...)
    # Make sure that res["sample"] is an array and use transpose
    samples, weights = transpose(Dynesty.PythonCall.pyconvert(Array, res["samples"])),
                       exp.(Dynesty.PythonCall.pyconvert(Vector, res["logwt"] - res["logz"][-1]))
    chain = transform.(Ref(post), eachcol(samples)) |> Table
    stats = (logl = Dynesty.PythonCall.pyconvert(Vector, res["logl"]),
             logz = Dynesty.PythonCall.pyconvert(Float64, res["logz"][-1]),
             logzerr = Dynesty.PythonCall.pyconvert(Float64, res["logz"][-1]),
             weights = weights,
             dynesty_obj = res
            )
    return Table(chain), stats
end



end
