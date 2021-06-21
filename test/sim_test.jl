using SimulationLogger
using DifferentialEquations
using Transducers
using Plots
using Test


function test()
    @Loggable function dynamics!(dx, x, p, t; u)
        @onlylog state = x  # __LOGGER_DICT__[:state] = x
        @onlylog input = u  # __LOGGER_DICT__[:input] = u
        dx .= u
    end
    @Loggable function feedback_dynamics!(dx, x, p, t)
        @onlylog time = t  # __LOGGER_DICT__[:time] = t
        @log x  # __LOGGER_DICT__[:x] = x
        @log u = -x  # __LOGGER_DICT__[:u] = -x
        @nested_log :linear dynamics!(dx, x, p, t; u=u)
    end
    t0, tf = 0.0, 1.0
    Δt = 0.01
    log_func(x, t, integrator::DiffEqBase.DEIntegrator; kwargs...) = feedback_dynamics!(zero.(x), copy(x), integrator.p, t, __LOG_INDICATOR__(); kwargs...)
    saved_values = SavedValues(Float64, Dict)
    cb = SavingCallback(log_func, saved_values;
                        saveat=t0:Δt:tf)
    # # sim
    x0 = [1, 2, 3]
    tspan = (t0, tf)
    prob = ODEProblem(
                      feedback_dynamics!, x0, tspan;
                      callback=cb,
                     )
    _ = solve(prob)
    ts = saved_values.t
    xs = saved_values.saveval |> Map(datum -> datum[:x]) |> collect
    us = saved_values.saveval |> Map(datum -> datum[:u]) |> collect
    states = saved_values.saveval |> Map(datum -> datum[:linear][:state]) |> collect
    inputs = saved_values.saveval |> Map(datum -> datum[:linear][:input]) |> collect
    @test xs == states
    @test us == inputs
    p_x = plot(ts, hcat(xs...)')
    p_u = plot(ts, hcat(us...)')
    dir_log = "figures"
    mkpath(dir_log)
    savefig(p_x, joinpath(dir_log, "state.png"))
end
