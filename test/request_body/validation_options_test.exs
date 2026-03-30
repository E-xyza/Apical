defmodule ApicalTest.RequestBody.ValidationOptionsTest do
  @moduledoc """
  Tests for request body validation options.

  This is Issue #52: Disable validation in request_body
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyValidationOptionsTest
        version: 1.0.0
      paths:
        "/validated":
          post:
            operationId: validatedBody
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
                    properties:
                      score:
                        type: integer
                        minimum: 0
                        maximum: 100
                    required:
                      - score
        "/not-validated":
          post:
            operationId: notValidatedBody
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
                    properties:
                      score:
                        type: integer
                        minimum: 0
                        maximum: 100
                    required:
                      - score
      """,
      root: "/",
      controller: ApicalTest.RequestBody.ValidationOptionsTest,
      content_type: "application/yaml",
      operation_ids: [
        notValidatedBody: [
          request_body: [validate: false]
        ]
      ]
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase

  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for operation <- ~w(validatedBody notValidatedBody)a do
    def unquote(operation)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  defp do_post(conn, route, payload) do
    content_length = byte_size(payload)

    conn
    |> Conn.put_req_header("content-length", "#{content_length}")
    |> Conn.put_req_header("content-type", "application/json")
    |> post(route, payload)
  end

  describe "with validation enabled (default)" do
    test "valid data passes", %{conn: conn} do
      result =
        conn
        |> do_post("/validated", ~s({"score": 50}))
        |> json_response(200)

      assert %{"score" => 50} = result
    end

    test "invalid data fails validation", %{conn: conn} do
      # score > 100 violates maximum constraint
      assert_raise ParameterError,
                   ~r/fails schema criterion.*maximum/,
                   fn ->
                     do_post(conn, "/validated", ~s({"score": 150}))
                   end
    end

    test "wrong type fails validation", %{conn: conn} do
      # string instead of integer
      assert_raise ParameterError,
                   ~r/fails schema criterion.*type/,
                   fn ->
                     do_post(conn, "/validated", ~s({"score": "fifty"}))
                   end
    end

    test "missing required field fails validation", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion.*required/,
                   fn ->
                     do_post(conn, "/validated", ~s({}))
                   end
    end
  end

  describe "with validation disabled (validate: false)" do
    test "valid data passes", %{conn: conn} do
      result =
        conn
        |> do_post("/not-validated", ~s({"score": 50}))
        |> json_response(200)

      assert %{"score" => 50} = result
    end

    test "invalid data passes without validation", %{conn: conn} do
      # score > 100 would normally violate maximum constraint
      result =
        conn
        |> do_post("/not-validated", ~s({"score": 150}))
        |> json_response(200)

      assert %{"score" => 150} = result
    end

    test "wrong type passes without validation", %{conn: conn} do
      # string instead of integer - no validation error
      result =
        conn
        |> do_post("/not-validated", ~s({"score": "fifty"}))
        |> json_response(200)

      assert %{"score" => "fifty"} = result
    end

    test "missing required field passes without validation", %{conn: conn} do
      result =
        conn
        |> do_post("/not-validated", ~s({}))
        |> json_response(200)

      assert %{} = result
    end
  end
end
