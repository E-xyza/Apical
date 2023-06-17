defmodule ApicalTest.CompileError.FormExplodedObjectTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule FormExplodedObjectFailsTest do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: FormExplodedObjectTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                parameters:
                  - name: parameter
                    required: true
                    in: query
                    style: form
                    explode: true
                    schema:
                      type: object
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
                 " Your schema violates the Apical requirement for parameter `parameter` in operation `fails`: form exploded parameters may not be objects",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
