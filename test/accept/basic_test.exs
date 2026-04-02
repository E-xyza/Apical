defmodule ApicalTest.Accept.BasicTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: AcceptBasicTest
        version: 1.0.0
      paths:
        "/json-only":
          get:
            operationId: jsonOnly
            responses:
              "200":
                description: JSON response
                content:
                  application/json:
                    schema:
                      type: object
        "/no-content":
          get:
            operationId: noContent
            responses:
              "204":
                description: No content response
      """,
      root: "/",
      controller: ApicalTest.Accept.BasicTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn
  alias Apical.Exceptions.NotAcceptableError

  for operation <- ~w(jsonOnly noContent)a do
    def unquote(operation)(conn, _params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
    end
  end

  describe "Accept header validation" do
    test "succeeds when Accept matches response type", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "returns 406 when Accept does not match response type", %{conn: conn} do
      assert_raise NotAcceptableError,
                   ~r/Accept header `text\/html` does not match available content types: application\/json/,
                   fn ->
                     conn
                     |> Plug.Conn.put_req_header("accept", "text/html")
                     |> get("/json-only")
                   end
    end

    test "succeeds when no Accept header is provided (RFC 7231)", %{conn: conn} do
      # Per RFC 7231: A request without any Accept header implies the user agent
      # will accept any media type in response.
      response = get(conn, "/json-only")
      assert %{"ok" => true} = json_response(response, 200)
    end

    test "skips validation when operation has no response content", %{conn: conn} do
      # Operations without defined response content should pass any Accept header
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "text/html")
        |> get("/no-content")

      assert response.status == 200
    end
  end
end
