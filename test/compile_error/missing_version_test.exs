defmodule ApicalTest.CompileError.MissingVersionTest do
  use ExUnit.Case, async: true
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule MissingVersion do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: MissingVersionTest
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
                 " Your schema violates the OpenAPI requirement that the schema `info` field has a `version` key",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
