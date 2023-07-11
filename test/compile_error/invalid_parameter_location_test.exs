defmodule ApicalTest.CompileError.InvalidParameterLocationTest do
  use ExUnit.Case, async: true

  import ApicalTest.Support.Error

  fails =
    quote do
      defmodule InvalidParameterLocation do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: InvalidParameterLocationTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                parameters:
                  - name: parameter
                    in: not-a-location
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

  test "invalid parameter location raises compile error" do
    assert_raise CompileError,
                 error_message(
                   "Your schema violates the OpenAPI requirement for parameters, invalid parameter location: `not-a-location` (in operation `fails`, parameter 0)"
                 ),
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
