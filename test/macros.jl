using SimulationLogger
using Zygote
using Test
using BangBang


function main()
    println(">"^10 * " log true " * "<"^10)
    _main(true)
    println(">"^10 * " log false " * "<"^10)
    _main(false)
end
"""
log = true or log = false
"""
function _main(log::Bool)
    test_log(log)
    test_nested_log(log)
    test_zygote()
    nothing
end

function test_zygote()
    println("#"^10 * " test_zygote " * "#"^10)
    function my_func(y)
        __LOGGER__ = NamedTuple()
        @show @log y
        @show @log x = y * 2
        result = __LOGGER__
    end
    @show my_func(1.0)  # function works?
    @test gradient(y -> my_func(y) |> sum, 1.0) == (3.0,)
end

function test_log(log)
    println("#"^10 * " test_log " * "#"^10)
    y = 2
    if log
        __LOGGER__ = NamedTuple()
        @show @log y
        @show @log x = y * 2
        @show __LOGGER__
        @test __LOGGER__ == (; y=2, x=4)
    else
        @show @log y
        @show @log x = y * 2
        @test !(@isdefined(__LOGGER__))
    end
end

function test_nested_log(log)
    println("#"^10 * " test_nested_log " * "#"^10)
    y1 = 2
    y2 = 4
    yy = 6
    if log
        __LOGGER__ = NamedTuple()
        @show @nested_log :values x = 1
        @test __LOGGER__ == (; values = (; x = 1))
        # @show @nested_log :values x = 2  # new assignment with the same key will yield an error
        @show @nested_log :values y1, y2
        @test __LOGGER__ == (; values = (; x = 1, y1=2, y2=4))
        @show @nested_log :values yy
        @test __LOGGER__ == (; values = (; x = 1, y1=2, y2=4, yy=6))
        @show @nested_log my_logging()
        @test __LOGGER__ == (; values = (; x = 1, y1=2, y2=4, yy=6, z=1))
        @show _w = @nested_log :good my_logging2()
        @test __LOGGER__ == (; values = (; x = 1, y1=2, y2=4, yy=6, z=1), good= (; w=3))
        @test _w == 3
        @show @nested_onlylog k = 1
        @test __LOGGER__ == (; values = (; x = 1, y1=2, y2=4, yy=6, z=1), good= (; w=3), k=1)
        @show @nested_onlylog :values j = 1
        @test __LOGGER__ == (; values = (; x = 1, y1=2, y2=4, yy=6, z=1, j=1), good= (; w=3), k=1)
        @show k
        @show __LOGGER__
    else
        @show @nested_log :values x = 1
        @show @nested_log :values y1, y2
        @show @nested_log :values yy
        @show @nested_log my_logging()
        @show _w = @nested_log :good my_logging2()
        @show @nested_onlylog :values j = 1  # @nested_onlylog produces `nothing`
        # @show k  # ERROR: UndefVarError: k not defined
        @test !(@isdefined(__LOGGER__))
    end
end

@Loggable function my_logging()
    @nested_log :values z = 1
end

@Loggable function my_logging2()
    @log w = 3
    w
end
