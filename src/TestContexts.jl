"""
Run multiple tests in a controlled context.

This provides the following features which are missing from the default `@testset` macro:

* Test cases are logged using `@debug`, to make it easier to debug and trace test execution.

* Test cases can be filtered using regular expression patterns, to allow debugging specific test
  cases.

* Each test case starts with a controlled environment whose content is independent from the other
  test cases. This environment can be created incrementally by nesting test sets, allowing
  setup/teardown steps to be reused for multiple test cases.
"""
module TestContexts

using Test

import Base: getproperty

export PrivateValue
export SharedValue
export tc
export test_case
export test_patterns
export PropertyValue
export test_set

mutable struct TestContext
    _patterns::Vector{Regex}
    _names::Vector{String}
    _data::Dict{Symbol,Any}
    _values::Union{Dict{Symbol,Any},Nothing}
    TestContext() = new(Vector{Regex}(), Vector{String}(), Dict{Symbol,Any}(), nothing)
end

"""
    SharedValue(value::Any)

A shared value will be used as-is by all tests. If the value is mutable, the test cases are
responsible to never change it (or at least ensure the original value is restored by the end of each
test).
"""
struct SharedValue
    value::Any
end

"""
    PrivateValue(make::Function, finalize::Union{Function,Nothing}=nothing)

A private value will be (lazily) re-created for each test (that accesses it) by invoking the `make`
function. This value can be mutated at will by the test case without affecting any other test case.
If the `finalize` function was specified, it is invoked at the end of each test case (that accessed
the value) and is given the value so it can be properly disposed of.
"""
struct PrivateValue
    make::Function
    finalize::Union{Function,Nothing}
    PrivateValue(make::Function, finalize::Union{Function,Nothing} = nothing) =
        new(make, finalize)
end

"""
Possible values for a test property.
"""
const PropertyValue = Union{SharedValue,PrivateValue}

function getproperty(context::TestContext, property::Symbol)::Any
    if String(property)[1] == '_'
        return getfield(context, property)
    end

    values = getfield(context, :_values)
    if values == nothing
        error(
            "Trying to access property $(property) of text context $(join(context._names, "/")) outside a test case",
        )
    end

    value = get(values, property, missing)
    if !ismissing(value)
        return value
    end

    property_value = get(getfield(context, :_data), property, missing)
    if ismissing(property_value)
        throw(
            KeyError(
                "Test context $(join(context._names, "/")) has no property named :$(property)",
            ),
        )
    end

    if property_value isa SharedValue
        value = property_value.value
    else
        @assert property_value isa PrivateValue
        value = property_value.make()
    end

    values[property] = value
    return value
end

"""
The global context for running tests.
"""
tc = TestContext()

"""
    test_patterns(patterns::Vector{Union{String,Regex}})::Nothing

Specify patterns for the tests to run. Only tests whose full name matches one of the patterns will
be run. If the vector is empty, all tests will be run.
"""
function test_patterns(patterns::Vector)::Nothing
    tc._patterns = [pattern isa Regex ? pattern : Regex(pattern) for pattern in patterns]

    return nothing
end

"""
    test_set(body::Function, name::String, data...)

Similar to @testset but uses the global `tc` test context for running tests under the given `name`.
The optional `data` must a series of zero or more entries, each in the format `property => value`
where `property` is a symbol and `value` is a `PropertyValue`.

Nesting test sets is allowed. This is a common pattern for incrementally setting up a test
environment for the actual test cases. In BDD terminology, a test set is functionally equivalent to
the "given" or "when" clauses.

The property values are not accessible (yet). See `test_case` for actually accessing the data.
"""
function test_set(body::Function, name::String, data...)::Nothing
    @assert tc._values == nothing
    push!(tc._names, name)
    data = Dict{Symbol,PropertyValue}(data...)
    for property in keys(data)
        if property in keys(tc._data)
            error(
                "Trying to override property $(property) of text context $(join(context._names, "/"))",
            )
        end
    end

    merge!(tc._data, data)

    try
        @testset "$name" begin
            body()
        end
    finally
        pop!(tc._names)
        for property in keys(data)
            delete!(tc._data, property)
        end
    end

    return nothing
end

"""
    test_case(body::Function, name::String, data...)

Similar to `test_set` but is used to wrap actual `@test` code. Allows access to any data previously
setup by the containing `test_set` calls, if any, is available during the test by accessing
`tc.property`. Mutable data (with a `make` function) is re-created (lazily) for each test case. If a
`finalize` function was specified, it is invoked to properly dispose of the data at the end of the
test case.

Nesting a test set or a test case inside a test case is forbidden. That is, a test case is expected
to actually test some specific scenario which was set up by the containing test sets. In BDD
terminology, a test case is functionally equivalent to the "then" clause.

The full name of the test case is the `/`-separated path containing all the names of the containing
`test_set` calls plus the final test case `name`. If `test_patterns` were specified, and the full
name does not match any of these patterns, then the test case is silently ignored.
"""
function test_case(body::Function, name::String, data...)::Nothing
    test_set(name, data...) do
        full_name = join(tc._names, "/")
        patterns = tc._patterns
        if !isempty(patterns)
            include = false

            for pattern in patterns
                if match(pattern, full_name) != nothing
                    include = true
                    break
                end
            end

            if !include
                return
            end
        end

        tc._values = Dict{String,Any}()

        try
            @testset "$name" begin
                @debug "Test $(full_name)..."
                body()
            end
        finally
            for (property, value) in tc._values
                property_value = tc._data[property]
                if property_value isa PrivateValue && property_value.finalize != nothing
                    property_value.finalize(value)
                end
            end

            tc._values = nothing
        end
    end
end

end # module
