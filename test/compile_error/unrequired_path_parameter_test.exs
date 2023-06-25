defmodule ApicalTest.CompileError.UnrequiredPathParameterTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule UnrequiredPathParameterFails do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: UnrequiredPathParameterTest
            version: 1.0.0
          paths:
            "/{parameter}":
              get:
                operationId: fails
                parameters:
                  - name: parameter
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

  test "unrequired path parameter raises compile error" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement for parameter `parameter` in operation `fails`: path parameters must be `required: true`",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
