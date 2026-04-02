defmodule ApicalTest.Refs.SecuritySchemeObjectTest do
  @moduledoc """
  Tests for $ref resolution in Security Scheme objects.

  Security schemes are referenced from the security field at:
  - Root level (applies to all operations)
  - Operation level (overrides root level)

  Note: Apical currently recommends using extra_plugs for security.
  This test verifies that schemas with security $refs compile correctly.
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: SecuritySchemeRefTest
        version: 1.0.0
      security:
        - ApiKeyAuth: []
      paths:
        "/public":
          get:
            operationId: publicEndpoint
            security: []
            responses:
              "200":
                description: Public endpoint
                content:
                  application/json:
                    schema:
                      type: object
        "/private":
          get:
            operationId: privateEndpoint
            security:
              - BearerAuth: []
            responses:
              "200":
                description: Private endpoint
                content:
                  application/json:
                    schema:
                      type: object
      components:
        securitySchemes:
          ApiKeyAuth:
            type: apiKey
            in: header
            name: X-API-Key
          BearerAuth:
            type: http
            scheme: bearer
            bearerFormat: JWT
      """,
      root: "/",
      controller: ApicalTest.Refs.SecuritySchemeObjectTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn

  for operation <- ~w(publicEndpoint privateEndpoint)a do
    def unquote(operation)(conn, _params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
    end
  end

  describe "security schemes in schema" do
    test "schema compiles successfully with security schemes", %{conn: conn} do
      # The schema should compile without errors even with security schemes
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get("/public")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "private endpoint also compiles with security requirement", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> get("/private")

      assert %{"ok" => true} = json_response(response, 200)
    end
  end
end
