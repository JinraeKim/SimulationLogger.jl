module SimulationLogger


using MacroTools
using BangBang

export @log, @onlylog, @Loggable, @nested_log, @nested_onlylog, __LOG_INDICATOR__

include("macros.jl")


end
