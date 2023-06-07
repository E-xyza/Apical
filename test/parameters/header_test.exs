defmodule ApicalTest.Parameters.PathTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: PathTest
        version: 1.0.0
      paths:
        "/required":
          get:
            operationId: headerParamRequired
            parameters:
              - name: required
                in: header
                required: true
      """,
      controller: ApicalTest.Parameters.PathTest,
      content_type: "application/yaml",
      styles: [{"x-custom", {__MODULE__, :x_custom}}],
      dump: true
    )

    def x_custom("foo"), do: 47
  end

  use ApicalTest.ConnCase
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  describe "for a required header parameter" do
    test "it serializes into required", %{conn: conn} do
      assert %{"required" => "foo"} = conn
        |> add_header("required", "foo")
        |> get("/required")
        |> json_response(200)
    end

    test "it fails when not present", %{conn: conn} do
      assert_raise ParameterError, "", fn ->
        get(conn, "/required")
      end
    end
  end
end
