defmodule ApicalTest.RequestBody.JsonTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyJsonTest
        version: 1.0.0
      paths:
        "/object":
          post:
            operationId: requestBodyJsonObject
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
      """,
      controller: ApicalTest.RequestBody.JsonTest,
      content_type: "application/yaml",
      dump: true
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for ops <- ~w(requestBodyJsonObject requestBodyJsonArray)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  defp do_post(conn, route, payload, content_type \\ "application/json") do
    conn
    |> Conn.put_req_header("content-type", content_type)
    |> post(route, Jason.encode!(payload))
  end

  describe "for posted object data" do
    test "it incorporates into params", %{conn: conn} do
      assert %{"foo" => "bar"} =
               conn
               |> do_post("/object", %{"foo" => "bar"})
               |> json_response(200)
    end

    test "passing wrong data", %{conn: conn} do
      assert_raise ParameterError, "Parameter Error in operation requestBodyJsonObject (in body): value [\"foo\", \"bar\"] at `/` fails schema criterion at `#/paths/~1object/post/requestBody/content/application~1json/schema/type`", fn ->
        do_post(conn, "/object", ["foo", "bar"])
      end
    end

    test "passing data with the wrong content-type"

    test "passing data with no content-type"
  end

  describe "object with nest_all_json option" do
    test "nests the json"
  end
end
