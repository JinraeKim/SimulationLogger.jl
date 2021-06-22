using SimulationLogger


function test()
    log = true
    test_nested_log(log)
    nothing
end

function test_nested_log(log)
    y = 2
    if log
        __LOGGER_DICT__ = Dict()
        @show @nested_log :values x = 1
        # @show @nested_log :values x = 2  # new assignment with the same key will yield an error
        @show @nested_log :values y
    else
        @show @nested_log :values x = 1
        @show @nested_log :values y
    end
end
