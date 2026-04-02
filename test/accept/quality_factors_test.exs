defmodule ApicalTest.Accept.QualityFactorsTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: AcceptQualityFactorsTest
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
      """,
      root: "/",
      controller: ApicalTest.Accept.QualityFactorsTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn
  alias Apical.Exceptions.NotAcceptableError

  def jsonOnly(conn, _params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
  end

  describe "Accept header with quality factors" do
    test "accepts type with lower quality factor when it matches", %{conn: conn} do
      # text/html;q=0.9, application/json;q=0.8 should match json
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "text/html;q=0.9, application/json;q=0.8")
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "rejects when q=0 explicitly disables the type", %{conn: conn} do
      # application/json;q=0 explicitly says "do not send json"
      assert_raise NotAcceptableError,
                   ~r/Accept header.*does not match available content types/,
                   fn ->
                     conn
                     |> Plug.Conn.put_req_header("accept", "application/json;q=0")
                     |> get("/json-only")
                   end
    end

    test "accepts when multiple types listed and one matches", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header(
          "accept",
          "text/html, application/xhtml+xml, application/json"
        )
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "handles complex Accept header with parameters", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header(
          "accept",
          "text/html, application/xhtml+xml, application/xml;q=0.9, application/json;q=0.8, */*;q=0.7"
        )
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end
  end
end
