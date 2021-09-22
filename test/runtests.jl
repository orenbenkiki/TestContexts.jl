using TestContexts
using Test

test_set("context") do
    @test_throws ErrorException tc.foo

    test_set("patterns") do
        test_patterns([".*/match"])
        try

            did_run_match = false
            test_case("match") do
                did_run_match = true
            end
            @test did_run_match

            did_run_mismatch = false
            test_case("mismatch") do
                did_run_mismatch = true  # untested
            end
            @test !did_run_mismatch

        finally
            test_patterns([])
        end
    end

    test_set("properties") do
        test_set("with_shared_foo", :foo => SharedValue("foo")) do
            test_case("with_shared_bar", :bar => SharedValue("bar")) do
                @test tc.foo == "foo"
                @test tc.bar == "bar"
            end

            test_case("without_bar") do
                @test tc.foo == "foo"
                @test_throws KeyError tc.bar
            end
        end

        did_make_foo = false
        test_set("with_private_foo", :foo => PrivateValue(() -> begin
            @test !did_make_foo
            did_make_foo = true
            "foo"
        end)) do
            test_case("ignore_foo") do
            end
            @test !did_make_foo

            test_case("access_foo") do
                @test tc.foo == "foo"
                @test tc.foo == "foo"
            end
            @test did_make_foo
        end

        did_make_foo = false
        did_finalize_foo = false
        test_set(
            "with_private_finalized_foo",
            :foo => PrivateValue(
                () -> begin
                    @test !did_make_foo
                    did_make_foo = true
                    "foo"
                end,
                (foo) -> begin
                    @test !did_finalize_foo
                    did_finalize_foo = true
                end,
            ),
        ) do
            test_case("ignore_foo") do
            end
            @test !did_make_foo
            @test !did_finalize_foo

            test_case("access_foo") do
                @test tc.foo == "foo"
                @test tc.foo == "foo"
            end
            @test did_make_foo
            @test did_finalize_foo
        end
    end
end
