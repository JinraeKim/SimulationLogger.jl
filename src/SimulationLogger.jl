module SimulationLogger


using MacroTools

export @log, @onlylog, @Loggable, @nested_log, __LOG_INDICATOR__

include("macros.jl")


end
