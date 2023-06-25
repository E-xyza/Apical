defmodule ApicalTest.CompileError.MissingPathsTest do
  use ExUnit.Case, async: true

  fails =
    quote do
      defmodule MissingPaths do
        require Apical
        use Phoenix.Router

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: MissingPathsTest
            version: 1.0.0
          """,
          controller: Undefined,
          encoding: "application/yaml"
        )
      end
    end

  @attempt_compile fails

  test "missing the paths section triggers compile failure" do
    assert_raise CompileError,
                 " Your schema violates the OpenAPI requirement that the schema has a `paths` key",
                 fn ->
                   Code.eval_quoted(@attempt_compile)
                 end
  end
end
