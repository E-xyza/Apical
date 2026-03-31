defmodule ApicalTest.RequestBody.ChunkedTest do
  @moduledoc """
  Tests for chunked transfer-encoding support.

  This is Issue #36: Chunked transfer-encoding
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: ChunkedTest
        version: 1.0.0
      paths:
        "/json-body":
          post:
            operationId: jsonBody
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
                    properties:
                      name:
                        type: string
                      count:
                        type: integer
      """,
      root: "/",
      controller: ApicalTest.RequestBody.ChunkedTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase

  alias Plug.Conn

  def jsonBody(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  describe "chunked transfer-encoding" do
    test "accepts request with transfer-encoding: chunked instead of content-length", %{
      conn: conn
    } do
      # Build a request with chunked transfer encoding (no content-length)
      payload = ~s({"name": "test", "count": 42})

      result =
        conn
        |> Conn.put_req_header("content-type", "application/json")
        |> Conn.put_req_header("transfer-encoding", "chunked")
        |> post("/json-body", payload)
        |> json_response(200)

      assert %{"name" => "test", "count" => 42} = result
    end

    test "still works with content-length header", %{conn: conn} do
      payload = ~s({"name": "test", "count": 42})

      result =
        conn
        |> Conn.put_req_header("content-type", "application/json")
        |> Conn.put_req_header("content-length", "#{byte_size(payload)}")
        |> post("/json-body", payload)
        |> json_response(200)

      assert %{"name" => "test", "count" => 42} = result
    end

    test "validates schema even with chunked encoding", %{conn: conn} do
      payload = ~s({"name": "test", "count": "not-an-integer"})

      assert_raise Apical.Exceptions.ParameterError,
                   ~r/fails schema criterion.*type/,
                   fn ->
                     conn
                     |> Conn.put_req_header("content-type", "application/json")
                     |> Conn.put_req_header("transfer-encoding", "chunked")
                     |> post("/json-body", payload)
                   end
    end
  end
end
