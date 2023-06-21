defmodule ApicalTest.CompileError.FormEncodedNonObjectTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule FormEncodedNonObjectFailsTest do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: FormEncodedNonObjectFailsTest
            version: 1.0.0
          paths:
            "/":
              get:
                operationId: fails
                requestBody:
                  content:
                    "application/x-www-form-urlencoded":
                      schema:
                        type: integer
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

  test "request body fails when it's form-encoded and the type is not \"object\"" do
    assert_raise CompileError,
                 " media type `application/x-www-form-urlencoded` does not support types other than object, found `\"integer\"` in operation `fails`",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
