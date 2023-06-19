defmodule ApicalTest.RequestBody.OtherTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyOtherTest
        version: 1.0.0
      paths:
        "/no-parser":
          post:
            operationId: requestBodyNoParser
            requestBody:
              content:
                "text/csv": {}
      """,
      root: "/",
      controller: ApicalTest.RequestBody.OtherTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase

  alias Plug.Parsers.UnsupportedMediaTypeError
  alias Plug.Conn

  for ops <-
        ~w(requestBodyNoParser)a do
    def unquote(ops)(conn, params) do
      [content_type] = Conn.get_req_header(conn, "content-type")

      conn
      |> Conn.put_resp_content_type(content_type)
      |> Conn.send_resp(200, "")
    end
  end

  defp do_post(conn, route, payload, content_type) do
    conn
    |> Conn.put_req_header("content-type", content_type)
    |> post(route, payload)
    |> Map.get(:resp_body)
  end

  describe "for posted object data" do
    test "it incorporates into params", %{conn: conn} do
      assert "foo" = do_post(conn, "/no-parser", "foo", "text/csv")
    end
  end
end
