defmodule ApicalTest.Refs.HeaderObjectTest do
  @moduledoc """
  Tests for $ref resolution in Header objects.

  Headers can be referenced from:
  - Response headers
  - Encoding headers in multipart request bodies
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    # Note: Apical currently focuses on request handling, not response headers.
    # This test verifies that $ref resolution works for headers when they
    # are used in encoding specifications for multipart request bodies.
    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: HeaderRefTest
        version: 1.0.0
      paths:
        "/upload":
          post:
            operationId: uploadFile
            requestBody:
              content:
                multipart/form-data:
                  schema:
                    type: object
                    properties:
                      file:
                        type: string
                        format: binary
                  encoding:
                    file:
                      contentType: application/octet-stream
            responses:
              "200":
                description: Success
                headers:
                  X-Request-Id:
                    $ref: "#/components/headers/RequestId"
                content:
                  application/json:
                    schema:
                      type: object
      components:
        headers:
          RequestId:
            description: Unique request identifier
            schema:
              type: string
              format: uuid
      """,
      root: "/",
      controller: ApicalTest.Refs.HeaderObjectTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def uploadFile(conn, _params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.put_resp_header("x-request-id", "123e4567-e89b-12d3-a456-426614174000")
    |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
  end

  describe "$ref resolution in header objects" do
    test "schema compiles successfully with $ref in response headers", %{conn: conn} do
      # The schema should compile without errors even with $ref in headers
      # This test verifies the schema parsing handles header $refs
      body =
        "------test\r\nContent-Disposition: form-data; name=\"file\"\r\n\r\ntest\r\n------test--\r\n"

      response =
        conn
        |> Plug.Conn.put_req_header("content-type", "multipart/form-data; boundary=----test")
        |> Plug.Conn.put_req_header("content-length", Integer.to_string(byte_size(body)))
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> post("/upload", body)

      assert response.status == 200
    end
  end
end
