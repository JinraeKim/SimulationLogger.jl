# SimulationLogger
SimulationLogger.jl is a package providing convenient logging tools for [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl).

## Packages related to SimulationLogger.jl
- [FlightSims.jl](https://github.com/JinraeKim/FlightSims.jl) is a general-purpose numerical simulator,
and it uses SimulationLogger.jl as a main loggin tool. You can find real examples about **how to use this package** in FlightSims.jl.

# TL; DR: example code
## Example 1: typical usage (see [FlightSims.jl](https://github.com/JinraeKim/FlightSims.jl) for details)

```julia
using SimulationLogger
using DifferentialEquations
using Transducers
using Plots
using Test


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
    xs = saved_values.saveval |> Map(datum -> datum[:x]) |> collect
    us = saved_values.saveval |> Map(datum -> datum[:u]) |> collect
    states = saved_values.saveval |> Map(datum -> datum[:state]) |> collect
    inputs = saved_values.saveval |> Map(datum -> datum[:input]) |> collect
    @test xs == states
    @test us == inputs
    p_x = plot(ts, hcat(xs...)')
    p_u = plot(ts, hcat(us...)')
    dir_log = "figures"
    mkpath(dir_log)
    savefig(p_x, joinpath(dir_log, "state.png"))
end
```
![ex_screenshot](./figures/x_lqr.png)
![ex_screenshot](./figures/u_lqr.png)

## Example 2: low-level usage
```julia
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
```
![ex_screenshot](./figures/state.png)


# Main macros
## `@Loggable`
`@Loggable` is a macro that makes an ODE function *loggable*.
### Example
```julia
@Loggable function dynamics!(dx, x, p, t)
    dx .= -x
end
```
### Mechanism
`@Loggable` generates additional method for the generic function of the annotated function definition.
The additional method receives `__log__indicator__::__LOG_INDICATOR__` as the last argument (other arguments are the same as the original function definition).
### Notice
- This macro should be used in front of "function definition". For example,
```julia
@Loggable function dynamics!(dx, x, p, t)
    dx .= -x
end
```
is good.
```julia
@Loggable dynamics! = (dx, x, p, t) -> dx .= -x
```
may not work properly.
- Functions annotated by `@Loggable` **MUST NOT** have `return` keyword. For example,
```julia
@Loggable function dynamics!(dx, x, p, t)
    dx .= -x
    nothing
end
```
works fine, but the logging functionality with `return`, for example,
```julia
@Loggable function dynamics!(dx, x, p, t)
    dx .= -x
    return nothing
end
```
may behave poorly.
## `@log`
This macro logs the annotated variable, and also executes the followed expression when *both solving DEProblem and logging data*.
### Example
```julia
@Loggable function dynamics!(dx, x, p, t)
    @log state = x
    @log p  # the same as `@log p = p`
    dx .= -x
end
```

## `@onlylog`
This macro logs the annotated variable, and also executes the followed expression *only when loggin data*.
### Example
```julia
@Loggable function dynamics!(dx, x, p, t)
    @log u = x
    @onlylog input = u   # `input` is not visible in this function when solving DEProblem.
    dx .= -u
end
```

## `@nested_log`
This macro logs (possibly) multiple data in a nested sense.
### Example
- [ ] Add an example

# NOTICE
- `__LOGGER_DICT__` is a privileged name to contain variables annotated by logging macros. **DO NOT USE THIS NAME IN USUAL CASE**.
- This package supports only [**in-place** method](https://diffeq.sciml.ai/stable/basics/problem/#In-place-vs-Out-of-Place-Function-Definition-Forms) of DifferentialEquations.jl.



# Notes
- This basic form of this macro is inspired by [SimulationLogs.jl](https://github.com/jonniedie/SimulationLogs.jl). But there are some differences. For example, `@log` in this package is based on [SavingCallback](https://diffeq.sciml.ai/stable/features/callback_library/#saving_callback), while `@log` in [SimulationLogs.jl](https://github.com/jonniedie/SimulationLogs.jl) will save data in the sense of postprocessing.
There are two main differences: this package can 1) log data without repeating the same code within differential equation (DE) functions, and 2) deal with stochastic parameter updates.
For more details, see [the original question](https://discourse.julialang.org/t/differentialequations-jl-saving-data-without-redundant-calculation-of-control-inputs/62559/3) and [the idea of this package](https://discourse.julialang.org/t/make-a-variable-as-a-global-variable-within-a-function/63067/21).
