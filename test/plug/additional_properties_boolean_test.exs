defmodule ApicalTest.Plug.AdditionalPropertiesBooleanTest do
  # Regression: `additionalProperties` is a boolean (`true`/`false`) OR a schema
  # object in OpenAPI 3.1. The request-body marshal context did
  # `get_in(schema, ["additionalProperties", "type"])`, which crashes when
  # `additionalProperties` is a boolean (`get_in(true, ["type"])` — booleans do
  # not implement Access). A well-formed spec using `additionalProperties: true`
  # only compiles if the boolean case is handled.
  use ApicalTest.EndpointCase, with: Plug
  alias Plug.Conn

  use Apical.Plug.Controller

  def openBody(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "a requestBody schema with `additionalProperties: true` compiles and accepts a body" do
    assert %{status: 200, body: "OK"} =
             Req.post!("http://localhost:#{@port}/", json: %{"anything" => "goes"})
  end
end

defmodule ApicalTest.Plug.AdditionalPropertiesBooleanTest.Router do
  use Apical.Plug.Router

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
            required: false
            content:
              application/json:
                schema:
                  type: object
                  additionalProperties: true
          responses:
            "200":
              description: OK
    """,
    for: Plug,
    root: "/",
    controller: ApicalTest.Plug.AdditionalPropertiesBooleanTest,
    content_type: "application/yaml"
  )
end
