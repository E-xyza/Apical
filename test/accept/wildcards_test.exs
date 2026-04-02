defmodule ApicalTest.Accept.WildcardsTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: AcceptWildcardsTest
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
        "/xml-only":
          get:
            operationId: xmlOnly
            responses:
              "200":
                description: XML response
                content:
                  application/xml:
                    schema:
                      type: object
      """,
      root: "/",
      controller: ApicalTest.Accept.WildcardsTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn

  for operation <- ~w(jsonOnly xmlOnly)a do
    def unquote(operation)(conn, _params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
    end
  end

  describe "Accept header wildcards" do
    test "*/* matches any content type", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "*/*")
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "application/* matches application/json", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/*")
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "application/* matches application/xml", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/*")
        |> get("/xml-only")

      assert response.status == 200
    end

    test "text/* does not match application/json", %{conn: conn} do
      assert_raise Apical.Exceptions.NotAcceptableError,
                   ~r/Accept header `text\/\*` does not match available content types/,
                   fn ->
                     conn
                     |> Plug.Conn.put_req_header("accept", "text/*")
                     |> get("/json-only")
                   end
    end

    test "wildcard with lower quality still matches", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "text/html, */*;q=0.1")
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end
  end
end
