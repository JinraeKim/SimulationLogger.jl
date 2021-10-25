"""
    __LOG_INDICATOR__()

Helper struct to specify a method as logging tool.
"""
struct __LOG_INDICATOR__
end


"""
# Notes
```julia
x = [ Dict("d1"=>"A1")
        Dict("d1b"=>Dict("d2a"=>"B1"))
         Dict("d1b"=>Dict("d2b"=>"C1"))
          Dict("d1b"=>Dict("d2c"=>Dict("d3a"=>"D1")))
           Dict("d1b"=>Dict("d2c"=>Dict("d3b"=>"E1")))]

julia> recursive_merge(x...) # with your last x
Dict{String,Any} with 2 entries:
  "d1"  => "A1"
  "d1b" => Dict{String,Any}("d2b"=>"C1","d2a"=>"B1","d2c"=>Dict("d3b"=>"E1","d3a"=>"D1"))
```
# References
https://discourse.julialang.org/t/multi-layer-dict-merge/27261/2?u=ihany
"""
function recursive_merge(x::AbstractDict...)
    merge(recursive_merge, x...)
end
function recursive_merge(x...)
    error("Invalid recursive_merge; did you assign values with the same key?
          For example,
          ```julia
          @nested_log :values x = 1
          @nested_log :values x = 2
          ```
          Otherwise, please report an issue.")
end


"""
    @Loggable(defun)

Generate two methods from a function definition (`defun`).

# Notes
Function definition with macro `@Loggable` will generate two methods with the same name (generic function).
For example,

```julia
@Loggable function dynamics!(dx, x, p, t; kwargs...)
    @log x
    dx = -x
end
```
will generate

```julia
function dynamics!(dx, x, p, t; kwargs...)
    @log x
    dx = -x
end
function dynamics!(dx, x, p, t, __log_indicator__::__LOG_INDICATOR__; kwargs...)
    __LOGGER_DICT__ = @isdefined(:__LOGGER_DICT__) ? __LOGGER_DICT__ : Dict()  # if isdefined, nested logging will work
    @log x
    dx = -x
    return __LOGGER_DICT__
end
```
"""
macro Loggable(defun)
    _def = splitdef(defun)  # original
    def = deepcopy(_def)
    _body = _def[:body]
    push!(def[:args], :(__log_indicator::__LOG_INDICATOR__))
    def[:body] = quote
        __LOGGER_DICT__ = @isdefined($(:__LOGGER_DICT__)) ? __LOGGER_DICT__ : Dict()
        $(_body.args...)  # remove the last line, return, to return __LOGGER_DICT__ 
        __LOGGER_DICT__  # return a Dict
    end
    res = quote
        $(MacroTools.combinedef(_def))  # the original method
        $(MacroTools.combinedef(def))  # the modified method
        $(def[:name])  # return methods
    end
    esc(res)
end

"""
    @log(__LOGGER_DICT__, expr)

A macro which logs annotated data (based on `expr`) to a privileged dictionary (`__LOGGER_DICT__`).
For example,
```julia
@Loggable function dynamics!(dx, x, p, t; kwargs...)
    @log x
    dx = -x
end
```
will generate

```julia
function dynamics!(dx, x, p, t; kwargs...)
    @log x
    dx = -x
end
function dynamics!(dx, x, p, t, __log_indicator__::__LOG_INDICATOR__; kwargs...)
    __LOGGER_DICT__ = @isdefined(:__LOGGER_DICT__) ? __LOGGER_DICT__ : Dict()  # if isdefined, nested logging will work
    @log x
    dx = -x
    return __LOGGER_DICT__
end
```
Then, if `@isdefined(__LOGGER_DICT__) == false`,
just evaluate given experssion `expr`.
Otherwise, @log(`expr`) will add a variable to `__LOGGER_DICT__` based on `expr`,
and also evaluate given experssion `expr`.
"""
macro log(__LOGGER_DICT__, expr)
    return if expr isa Symbol  # @log x
        quote
            local val = $(esc(expr))
            local var_name = $((expr,))[1]
            local logger_dict = $(esc(__LOGGER_DICT__))
            haskey(logger_dict, var_name) ? error("Already defined key: $(var_name)") : setindex!(logger_dict, val, var_name)
            nothing
        end
    elseif expr.head == :(=)
        if expr.args[1] isa Expr && expr.args[1].head == :tuple  # @log x, y = a, b
            quote
                local vals = $(esc(expr.args[2]))
                local var_names = $(esc(expr.args[1].args))
                local logger_dict = $(esc(__LOGGER_DICT__))
                for (var_name, val) in zip(var_names, vals)
                    haskey(logger_dict, var_name) ? error("Already defined key: $(var_name)") : setindex!(logger_dict, val, var_name)
                end
                $(esc(expr))
            end
        else  # @log x = a
            quote
                local val = $(esc(expr.args[2]))
                local var_name = $((expr.args[1],))[1]
                local logger_dict = $(esc(__LOGGER_DICT__))
                haskey(logger_dict, var_name) ? error("Already defined key: $(var_name)") : setindex!(logger_dict, val, var_name)
                $(esc(expr))
            end
        end
    elseif expr.args isa Array  # @log x, y
        quote
            local vals = $(esc(expr))
            local var_names = $(esc((expr.args)))
            local logger_dict = $(esc(__LOGGER_DICT__))
            for (var_name, val) in zip(var_names, vals)
                haskey(logger_dict, var_name) ? error("Already defined key: $(var_name)") : setindex!(logger_dict, val, var_name)
            end
            $(esc(expr))
        end
    else
        :(error("To log a variable, use either one of forms: `@log val` or `@log var_name = val`"))
    end
end

macro log(expr)
    esc(:(@isdefined($:__LOGGER_DICT__) ? @log($:__LOGGER_DICT__, $expr) : $expr))
end

"""
    @onlylog(expr)

A macro that activates given expression (`expr`) only when logging data.
Unlike `@log(expr)`,
this macro does not evaluate given experssion `expr`.
"""
macro onlylog(expr)
    esc(:(@isdefined($:__LOGGER_DICT__) ? @log($:__LOGGER_DICT__, $expr) : nothing))
end

"""
    @nested_log(symbol, expr)

A macro that enables us to log data in a nested sense.
# Examples
- Example 1
```julia
@nested_log :subsystem dynamics!(dx.sub, x.sub, p.sub, t)
```
will log data from `dynamics!(dx.sub, x.sub, p.sub, t)` as
`__LOGGER_DICT__[:subsystem]`.
- Example 2
```julia
@nested_log :subsystem state = x
```

# NOTICE
If you assign values with the two same keys, it will yield an error looks like:
```julia
ERROR: MethodError: no method matching recursive_merge(::Int64, ::Int64)
```
"""
macro nested_log(__LOGGER_DICT__, symbol, expr)
    if expr isa Symbol
        res = quote
            local logger_dict = $(__LOGGER_DICT__)
            __TMP_DICT__ = Dict()
            @log(__TMP_DICT__, $expr)
            if $symbol == nothing
                __LOGGER_DICT__ = $recursive_merge([logger_dict, __TMP_DICT__]...)
            else
                if haskey(logger_dict, $symbol)
                    logger_dict[$symbol] = $recursive_merge([logger_dict[$symbol], __TMP_DICT__]...)
                else
                    setindex!(logger_dict, __TMP_DICT__, $symbol)
                end
            end
            $expr
        end
        esc(res)
    elseif expr.head == :call
        _expr = copy(expr)
        push!(_expr.args, :(__LOG_INDICATOR__()))
        res = quote
            local logger_dict = $(__LOGGER_DICT__)
            __TMP_DICT__ = Dict()
            __TMP_DICT__ = $recursive_merge([__TMP_DICT__, $_expr]...)
            if $symbol == nothing
                __LOGGER_DICT__ = $recursive_merge([logger_dict, __TMP_DICT__]...)
            else
                if haskey(logger_dict, $symbol)
                    logger_dict[$symbol] = $recursive_merge([logger_dict[$symbol], __TMP_DICT__]...)
                else
                    setindex!(logger_dict, $_expr, $symbol)
                end
            end
            $expr
        end
        esc(res)
    elseif expr.head == :(=)  # @nested_log env_name x = a  or  @nested_log env_name x, y = a, b
        res = quote
            local logger_dict = $(__LOGGER_DICT__)
            __TMP_DICT__ = Dict()
            @log(__TMP_DICT__, $expr)
            if $symbol == nothing
                __LOGGER_DICT__ = $recursive_merge([logger_dict, __TMP_DICT__]...)  # 'cause it is not in-place.
            else
                if haskey(logger_dict, $symbol)
                    logger_dict[$symbol] = $recursive_merge([logger_dict[$symbol], __TMP_DICT__]...)
                else
                    setindex!(logger_dict, __TMP_DICT__, $symbol)
                end
            end
            $expr
        end
        esc(res)
    elseif expr.args isa Array  # @nested_log env_name a, b
        res = quote
            local logger_dict = $(__LOGGER_DICT__)
            __TMP_DICT__ = Dict()
            @log(__TMP_DICT__, $expr)
            if $symbol == nothing
                __LOGGER_DICT__ = $recursive_merge([logger_dict, __TMP_DICT__]...)  # 'cause it is not in-place.
            else
                if haskey(logger_dict, $symbol)
                    logger_dict[$symbol] = $recursive_merge([logger_dict[$symbol], __TMP_DICT__]...)
                else
                    setindex!(logger_dict, __TMP_DICT__, $symbol)
                end
            end
            $expr
        end
        esc(res)
    else
        error_invalid_expr_head()
    end
end

macro nested_log(symbol, expr)
    esc(:(@isdefined($:__LOGGER_DICT__) ? @nested_log($:__LOGGER_DICT__, $symbol, $expr) : $expr))
end

macro nested_log(expr)
    if expr isa Symbol  # @nested_log x
        res = quote
            @nested_log(esc($expr), $expr)  # __LOGGER_DICT__[:x] = x
        end
        esc(res)
    elseif expr.head == :call  # @nested_log my_func() where my_func() = dict
        _expr = copy(expr)
        push!(_expr.args, :(__LOG_INDICATOR__()))  # to distinguish whether call extended function with __LOGGER_DICT__ or not (in advance)
        res = quote
            if @isdefined($:__LOGGER_DICT__)
                __LOGGER_DICT__ = $recursive_merge([__LOGGER_DICT__, $_expr]...)
                # $expr
            # else
            #     $expr
            end
            $expr
        end
        esc(res)
    else
        error_invalid_expr_head()
    end
end

"""
    @nested_onlylog(symbol, expr)

A macro that activates given expression (`expr`) only when logging data.
Unlike `@nested_log(symbol, expr)`,
this macro does not evaluate given experssion `expr`.
"""
macro nested_onlylog(symbol, expr)
    esc(:(@isdefined($:__LOGGER_DICT__) ? @nested_log($:__LOGGER_DICT__, $symbol, $expr) : nothing))
end

"""
    @nested_onlylog(expr)

A macro that activates given expression (`expr`) only when logging data.
Unlike `@nested_log(expr)`,
this macro does not evaluate given experssion `expr`.
"""
macro nested_onlylog(expr)
    esc(:(@isdefined($:__LOGGER_DICT__) ? @nested_log($:__LOGGER_DICT__, nothing, $expr) : nothing))
end


# etc
function error_invalid_expr_head()
    error("Invalid expression head")
end
