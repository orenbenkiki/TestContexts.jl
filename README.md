# TestContexts

Run multiple tests in a controlled context.

This provides the following features which are missing from the default `@testset` macro:

* Test cases are logged using `@debug`, to make it easier to debug and trace test execution.

* Test cases can be filtered using regular expression patterns, to allow debugging specific test
  cases.

* Each test case starts with a controlled environment whose content is independent from the other
  test cases. This environment can be created incrementally by nesting test sets, allowing
  setup/teardown steps to be reused for multiple test cases.

See the [Documentation](https://orenbenkiki.github.io/TestContexts.jl/) for details.
