defmodule ApicalTest.CompileError.MissingOpenApiTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule MissingOpenApi do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          info:
            title: MissingOpenApiTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                parameters:
                  - name: parameter
                    in: query
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

  test "missing the openapi section triggers compile failure" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement that the schema has an `openapi` key",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
