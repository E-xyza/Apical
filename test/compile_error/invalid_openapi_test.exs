defmodule ApicalTest.CompileError.InvalidOpenApiTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule InvalidOpenApi do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: foo
          info:
            title: InvalidOpenApiTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                parameters:
                  - name: parameter
                    in: query
                  - name: parameter
                    in: header
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

  test "an invalid openapi section triggers compile failure" do
    assert_raise CompileError,
                 "",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
