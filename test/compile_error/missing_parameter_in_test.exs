defmodule ApicalTest.CompileError.MissingParameterInTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule MissingParameterIn do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: MissingParameterInTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                parameters:
                  - name: parameter
                responses:
                  "200":
                    description: OK
          """,
          controller: Undefined,
          content_type: "application/yaml"
        )
      end
    end

  @attempt_compile fails

  test "invalid parameter location raises compile error" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement for parameters, field `in` is required (in operation `fails`, parameter 0)",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
