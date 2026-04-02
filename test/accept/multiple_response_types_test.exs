defmodule ApicalTest.Accept.MultipleResponseTypesTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: AcceptMultipleTypesTest
        version: 1.0.0
      paths:
        "/both":
          get:
            operationId: bothTypes
            responses:
              "200":
                description: Response with multiple content types
                content:
                  application/json:
                    schema:
                      type: object
                  application/xml:
                    schema:
                      type: object
      """,
      root: "/",
      controller: ApicalTest.Accept.MultipleResponseTypesTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn
  alias Apical.Exceptions.NotAcceptableError

  def bothTypes(conn, _params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
  end

  describe "Accept header with multiple response types" do
    test "accepts application/json when both json and xml available", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get("/both")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "accepts application/xml when both json and xml available", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/xml")
        |> get("/both")

      assert response.status == 200
    end

    test "returns 406 when neither matches", %{conn: conn} do
      assert_raise NotAcceptableError,
                   ~r/Accept header `text\/plain` does not match available content types/,
                   fn ->
                     conn
                     |> Plug.Conn.put_req_header("accept", "text/plain")
                     |> get("/both")
                   end
    end
  end
end
