defmodule ApicalTest.CompileError.MissingParameterNameTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule MissingParameterName do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: MissingParameterNameTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                parameters:
                  - in: query
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

  test "missing parameter name raises compile error" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement for parameters, field `name` is required (in operation `fails`, parameter 0)",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
