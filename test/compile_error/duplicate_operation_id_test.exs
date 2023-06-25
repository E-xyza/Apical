defmodule ApicalTest.CompileError.DuplicateOperationIdTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule DuplicateOperationId do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: DuplicateOperationIdTest
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
            "/other":
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

  test "nonunique operation ids compile error" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement that operationIds are unique: (got more than one `fails`)",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
