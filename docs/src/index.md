# TestContexts

```@docs
TestContexts.TestContexts
```

## The global test context

The global `tc` object is used to configure and access the tests context.

```@docs
TestContexts.tc
```

## Setting up the test environment

For the common case when multiple test cases require the same initial data, one can invoke
`test_set`. This works similarly to a "given" or "when" clause in BDD. The data is stored
inside the global `tc` context.

```@docs
TestContexts.PropertyValue
TestContexts.SharedValue
TestContexts.PrivateValue
TestContexts.test_set
```

## Running tests

To actually run tests, invoke `test_case` (typically nested within one or more `test_set` calls).
Each test case will be logged using `@debug` before it starts execution.

```@docs
TestContexts.test_case
```

## Controlling test execution

Invoking `test_patterns` allows specifying a list of patterns of full test names. If this list is
not empty, only tests which match at least one of the patterns will actually execute:

```@docs
TestContexts.test_patterns
```

## Example

In the following example, we have two test cases, `db/filled` and `db/empty`. Each of these test
cases starts with a fresh copy of the database, which is deleted when the test case is done.

```
test_set("db", :db => PrivateValue(create_db_on_disk, remove_db_from_disk)) do
    test_case("filled") do
        fill_db(tc.db)
        @test ...
    end
    test_case("empty") do
        @test ...
    end
end
```

If we invoke:

```
test_patterns(['.*/filled'])
```

Then running the tests will only execute the `db/filled` test case. A common usage is to add
`test_patterns(Base.ARGS)` as the 1st executable line of `runtests.jl`, which allows specifying
which tests to run on the command line.
