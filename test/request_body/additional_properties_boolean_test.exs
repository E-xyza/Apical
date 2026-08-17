defmodule ApicalTest.RequestBody.AdditionalPropertiesBooleanTest do
  # Regression: `additionalProperties` is a boolean (`true`/`false`) OR a schema
  # object in OpenAPI 3.1. The request-body marshal context did
  # `get_in(schema, ["additionalProperties", "type"])`, which crashes when
  # `additionalProperties` is a boolean (`get_in(true, ["type"])` — booleans do
  # not implement Access). This runs on BOTH adapters (RequestBody.make is called
  # before the adapter split), so it broke Phoenix too, not just Plug.
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: AdditionalPropertiesBoolean
        version: 1.0.0
      paths:
        "/":
          post:
            operationId: openBody
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
                    additionalProperties: true
      """,
      root: "/",
      controller: ApicalTest.RequestBody.AdditionalPropertiesBooleanTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase

  alias Plug.Conn
  alias ApicalTest.RequestBody.AdditionalPropertiesBooleanTest.Endpoint

  def openBody(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  defp do_post(conn, route, payload) do
    payload_binary = Jason.encode!(payload)

    conn
    |> Conn.put_req_header("content-type", "application/json")
    |> Conn.put_req_header("content-length", "#{byte_size(payload_binary)}")
    |> post(route, payload_binary)
  end

  test "a requestBody with `additionalProperties: true` compiles and accepts a body", %{
    conn: conn
  } do
    assert %{"anything" => "goes"} =
             conn
             |> do_post("/", %{"anything" => "goes"})
             |> json_response(200)
  end
end
