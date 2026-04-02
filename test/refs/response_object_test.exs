defmodule ApicalTest.Refs.ResponseObjectTest do
  @moduledoc """
  Tests for $ref resolution in Response objects.
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: ResponseRefTest
        version: 1.0.0
      paths:
        "/with-ref":
          get:
            operationId: withResponseRef
            responses:
              "200":
                $ref: "#/components/responses/JsonResponse"
        "/with-inline":
          get:
            operationId: withInlineResponse
            responses:
              "200":
                description: Inline response
                content:
                  application/json:
                    schema:
                      type: object
        "/with-nested-ref":
          get:
            operationId: withNestedRef
            responses:
              "200":
                $ref: "#/components/responses/XmlResponse"
      components:
        responses:
          JsonResponse:
            description: A JSON response
            content:
              application/json:
                schema:
                  type: object
          XmlResponse:
            description: An XML response
            content:
              application/xml:
                schema:
                  type: object
      """,
      root: "/",
      controller: ApicalTest.Refs.ResponseObjectTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn
  alias Apical.Exceptions.NotAcceptableError

  for operation <- ~w(withResponseRef withInlineResponse withNestedRef)a do
    def unquote(operation)(conn, _params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
    end
  end

  describe "$ref resolution in response objects" do
    test "resolves $ref to components/responses for Accept validation", %{conn: conn} do
      # This should pass because the $ref resolves to a response with application/json
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get("/with-ref")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "rejects non-matching Accept header with $ref response", %{conn: conn} do
      # The $ref resolves to JsonResponse which only has application/json
      assert_raise NotAcceptableError,
                   ~r/Accept header `text\/html` does not match available content types: application\/json/,
                   fn ->
                     conn
                     |> Plug.Conn.put_req_header("accept", "text/html")
                     |> get("/with-ref")
                   end
    end

    test "inline responses work as expected", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get("/with-inline")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "resolves $ref to XML response correctly", %{conn: conn} do
      # This should pass because the $ref resolves to a response with application/xml
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/xml")
        |> get("/with-nested-ref")

      assert response.status == 200
    end

    test "rejects JSON Accept when response only has XML", %{conn: conn} do
      # The XmlResponse only has application/xml
      assert_raise NotAcceptableError,
                   ~r/Accept header `application\/json` does not match available content types: application\/xml/,
                   fn ->
                     conn
                     |> Plug.Conn.put_req_header("accept", "application/json")
                     |> get("/with-nested-ref")
                   end
    end
  end
end
