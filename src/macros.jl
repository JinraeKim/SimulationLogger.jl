"""
    __LOG_INDICATOR__()

Helper struct to specify a method as logging tool.
"""
struct __LOG_INDICATOR__
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
        $(MacroTools.combinedef(_def))
        $(MacroTools.combinedef(def))
        $(def[:name])
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
    @onlylog(symbol, expr)

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
"""
macro nested_log(symbol, expr)
    if expr.head == :call
        _expr = deepcopy(expr)
        push!(expr.args, :(__LOG_INDICATOR__()))
        res = quote
            if @isdefined($:__LOGGER_DICT__)
                haskey(__LOGGER_DICT__, $symbol) ? error("Already defined key: $(symbol)") : setindex!(__LOGGER_DICT__, $expr, $symbol)
            else
                $_expr
            end
        end
        esc(res)
    elseif expr.head == :(=)
        _expr = deepcopy(expr)
        res = quote
            if @isdefined($:__LOGGER_DICT__)
                __TMP_DICT__ = Dict()
                @log(__TMP_DICT__, $expr)
                haskey(__LOGGER_DICT__, $symbol) ? merge(__LOGGER_DICT__[$symbol], __TMP_DICT__) : setindex!(__LOGGER_DICT__, __TMP_DICT__, $symbol)
            else
                $_expr
            end
        end
        esc(res)
    else
        error_invalid_expr_head()
    end
end

macro nested_log(expr)
    if expr.head == :call
        _expr = deepcopy(expr)
        push!(expr.args, :(__LOG_INDICATOR__()))
        res = quote
            if @isdefined($:__LOGGER_DICT__)
                __LOGGER_DICT__ = merge(__LOGGER_DICT__, $expr)
            else
                $_expr
            end
        end
        esc(res)
    else
        error_invalid_expr_head()
    end
end

function error_invalid_expr_head()
    error("Invalid expression head")
    # error("Call the ODE function of a sub-environment, e.g., `@nested_log :env_name dynamics!(dx.sub, x.sub, p.sub, t)`")
end
