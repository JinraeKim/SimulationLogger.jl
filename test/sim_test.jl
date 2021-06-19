using SimulationLogger
using DifferentialEquations
using Transducers
using Plots


function test()
    @Loggable function dynamics!(dx, x, p, t)
        @log x
        @log u = -x
        @onlylog state = x
        @onlylog input = u
        dx .= u
    end
    t0, tf = 0.0, 10.0
    Δt = 0.01
    log_func(x, t, integrator::DiffEqBase.DEIntegrator; kwargs...) = dynamics!(zero.(x), copy(x), integrator.p, t, __LOG_INDICATOR__(); kwargs...)
    saved_values = SavedValues(Float64, Dict)
    cb = SavingCallback(log_func, saved_values;
                        saveat=t0:Δt:tf)
    # # sim
    x0 = [1, 2, 3]
    tspan = (t0, tf)
    prob = ODEProblem(
                      dynamics!, x0, tspan;
                      callback=cb,
                     )
    _ = solve(prob)
    ts = saved_values.t
    xs = saved_values.saveval |> Map(datum -> datum[:state]) |> collect
    us = saved_values.saveval |> Map(datum -> datum[:input]) |> collect
    p_x = plot(ts, hcat(xs...)')
    p_u = plot(ts, hcat(us...)')
    dir_log = "figures"
    mkpath(dir_log)
    savefig(p_x, joinpath(dir_log, "state.png"))
end
