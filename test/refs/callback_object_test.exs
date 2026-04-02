defmodule ApicalTest.Refs.CallbackObjectTest do
  @moduledoc """
  Tests for $ref resolution in Callback objects.

  Callbacks define webhook endpoints that the API will call.
  They can be defined inline or referenced from components/callbacks.
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: CallbackRefTest
        version: 1.0.0
      paths:
        "/subscribe":
          post:
            operationId: subscribe
            requestBody:
              content:
                application/json:
                  schema:
                    type: object
                    properties:
                      callbackUrl:
                        type: string
                        format: uri
            callbacks:
              onEvent:
                $ref: "#/components/callbacks/EventCallback"
            responses:
              "200":
                description: Subscription created
                content:
                  application/json:
                    schema:
                      type: object
        "/simple":
          get:
            operationId: simpleEndpoint
            responses:
              "200":
                description: Simple endpoint
                content:
                  application/json:
                    schema:
                      type: object
      components:
        callbacks:
          EventCallback:
            "{$request.body#/callbackUrl}":
              post:
                requestBody:
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          event:
                            type: string
                responses:
                  "200":
                    description: Callback acknowledged
      """,
      root: "/",
      controller: ApicalTest.Refs.CallbackObjectTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn

  for operation <- ~w(subscribe simpleEndpoint)a do
    def unquote(operation)(conn, _params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
    end
  end

  describe "callback $ref resolution" do
    test "schema compiles successfully with callback $ref", %{conn: conn} do
      # The schema should compile without errors even with callback $refs
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get("/simple")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "subscribe endpoint with callbacks compiles correctly", %{conn: conn} do
      body = Jason.encode!(%{callbackUrl: "https://example.com/callback"})

      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("content-length", Integer.to_string(byte_size(body)))
        |> post("/subscribe", body)

      assert %{"ok" => true} = json_response(response, 200)
    end
  end
end
