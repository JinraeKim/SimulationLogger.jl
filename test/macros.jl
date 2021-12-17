using SimulationLogger
using Zygote
using Test
using BangBang


"""
log = true or log = false
"""
function test(log::Bool)
    test_log(log)
    test_nested_log(log)
    test_zygote(:nt)  # works well with BangBang's !! syntax
    test_zygote(:dict)  # may not work
    nothing
end

function test_zygote(type)
    println("#"^10 * " test_zygote (type = $(type))" * "#"^10)
    function my_func(y; type)
        result = nothing
        if type == :dict
            __LOGGER_DICT__ = Dict()
            @show @log y
            @show @log x = y * 2
            result = __LOGGER_DICT__ |> values |> sum
        elseif type == :nt
            __LOGGER_NT__ = NamedTuple()
            # TODO: replace the following test lines with modified @log for NamedTuple
            __LOGGER_NT__ = setindex!!(__LOGGER_NT__, y, :y)
            __LOGGER_NT__ = setindex!!(__LOGGER_NT__, 2*y, :x)
            result = __LOGGER_NT__ |> sum
        else
            error("")
        end
        result
    end
    @show my_func(1.0; type=type)  # function works?
    @test gradient(y -> my_func(y; type), 1.0) == (3.0,)
end

function test_log(log)
    println("#"^10 * " test_log " * "#"^10)
    y = 2
    if log
        __LOGGER_DICT__ = Dict()
        @show @log y
        @show @log x = y * 2
        @show __LOGGER_DICT__
    else
        @show @log y
        @show @log x = y * 2
    end
end

function test_nested_log(log)
    println("#"^10 * " test_nested_log " * "#"^10)
    y1 = 2
    y2 = 4
    yy = 6
    if log
        __LOGGER_DICT__ = Dict()
        @show @nested_log :values x = 1
        # @show @nested_log :values x = 2  # new assignment with the same key will yield an error
        @show @nested_log :values y1, y2
        @show @nested_log :values yy
        @show @nested_log my_logging()
        @show _w = @nested_log :good my_logging2()
        @show @nested_onlylog k = 1
        @show @nested_onlylog :values j = 1
        @show k
        @show __LOGGER_DICT__
    else
        @show @nested_log :values x = 1
        @show @nested_log :values y1, y2
        @show @nested_log :values yy
        @show @nested_log my_logging()
        @show _w = @nested_log :good my_logging2()
        @show @nested_onlylog :values j = 1  # @nested_onlylog produces `nothing`
        @show k  # ERROR: UndefVarError: k not defined
    end
end

@Loggable function my_logging()
    @nested_log :values z = 1
end

@Loggable function my_logging2()
    @log w = 3
    w
end
