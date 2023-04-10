defmodule ApicalTest.Parameters.QueryTest do
  defmodule Router do
    use Phoenix.Router

    require Apical
    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: QueryTest
        version: 1.0.0
      paths:
        "/":
          get:
            operationId: queryTest
            parameters:
              - name: required
                in: query
                required: true
              - name: optional
                in: query
              - name: allowEmptyValue
                in: query
                allowEmptyValue: true
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Parameters.QueryTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def queryTest(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  describe "for a required query parameter" do
    test "it serializes into required", %{conn: conn} do
      assert %{"required" => "foo"} = json_response(get(conn, "/?required=foo"), 200)
    end

    test "it fails when not present", %{conn: conn} do
      assert %{status: 400} = get(conn, "/")
    end
  end
end
