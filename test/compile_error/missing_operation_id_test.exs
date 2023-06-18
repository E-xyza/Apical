defmodule ApicalTest.CompileError.MissingOperationIdTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule MissingOperationIdFailsTest do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: MissingOperationIdTest
            version: 1.0.0
          paths:
            "/":
              get:
                parameters:
                  - name: parameter
                    in: query
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

  test "nonexistent path parameter raises compile error" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement that all operations have an operationId: (missing for operation at `/paths/~1/get`)",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
