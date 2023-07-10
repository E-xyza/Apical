defmodule ApicalTest.CompileError.InvalidOpenApiTest do
  use ExUnit.Case, async: true

  import ApicalTest.Support.Error

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

  test "an invalid openapi section triggers compile failure" do
    assert_raise CompileError,
                 error_message("Your schema violates the Apical requirement that the schema has a supported `openapi` version (got `foo`)"),
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
