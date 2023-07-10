defmodule ApicalTest.CompileError.DuplicateParameterTest do
  use ExUnit.Case, async: true

  import ApicalTest.Support.Error

  fails =
    quote do
      defmodule DuplicateParameter do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: DuplicateParameterTest
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
          encoding: "application/yaml"
        )
      end
    end

  @attempt_compile fails

  test "duplicate parameter raises compile error" do
    assert_raise CompileError,
                 error_message("Your schema violates the OpenAPI requirement for unique parameters: the parameter `parameter` is not unique (in operation `fails`)"),
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
