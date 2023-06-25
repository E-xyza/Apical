defmodule ApicalTest.CompileError.NonexistentPathParameterTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule NonexistentPathParameterFails do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: NonexistentPathParameterTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                parameters:
                  - name: parameter
                    required: true
                    in: path
                responses:
                  "200":
                    description: OK
          """,
          controller: Undefined,
          encoding: "application/yaml"
        )
      end
    end

  @attempt_compile fails

  test "nonexistent path parameter raises compile error" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement that the parameter `parameter` in operation `fails` exists as a match in its path definition: (got: `/`)",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
