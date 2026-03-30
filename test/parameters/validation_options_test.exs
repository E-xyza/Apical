defmodule ApicalTest.Parameters.ValidationOptionsTest do
  @moduledoc """
  Tests for parameter validation options.

  This is Issue #40: Disable automatic validation of schemas
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: ValidationOptionsTest
        version: 1.0.0
      paths:
        "/with-validation":
          get:
            operationId: withValidation
            parameters:
              - name: value
                in: query
                required: true
                schema:
                  type: integer
                  minimum: 0
                  maximum: 100
        "/without-validation":
          get:
            operationId: withoutValidation
            parameters:
              - name: value
                in: query
                required: true
                schema:
                  type: integer
                  minimum: 0
                  maximum: 100
        "/per-param-validation":
          get:
            operationId: perParamValidation
            parameters:
              - name: validated
                in: query
                schema:
                  type: integer
              - name: unvalidated
                in: query
                schema:
                  type: integer
      """,
      root: "/",
      controller: ApicalTest.Parameters.ValidationOptionsTest,
      content_type: "application/yaml",
      operation_ids: [
        withoutValidation: [validate: false],
        perParamValidation: [
          parameters: [
            unvalidated: [validate: false]
          ]
        ]
      ]
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase

  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  def withValidation(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  def withoutValidation(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  def perParamValidation(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  describe "with validation enabled (default)" do
    test "valid values pass", %{conn: conn} do
      result =
        conn
        |> get("/with-validation?value=50")
        |> json_response(200)

      assert %{"value" => 50} = result
    end

    test "invalid values fail validation", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion/,
                   fn ->
                     get(conn, "/with-validation?value=200")
                   end
    end

    test "wrong type fails validation", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion.*type/,
                   fn ->
                     get(conn, "/with-validation?value=not-an-integer")
                   end
    end
  end

  describe "with validation disabled at operation level" do
    test "valid values still pass", %{conn: conn} do
      result =
        conn
        |> get("/without-validation?value=50")
        |> json_response(200)

      assert %{"value" => 50} = result
    end

    test "out-of-range values pass without validation", %{conn: conn} do
      # Would normally fail minimum/maximum validation
      result =
        conn
        |> get("/without-validation?value=200")
        |> json_response(200)

      assert %{"value" => 200} = result
    end

    test "wrong type still marshals but skips schema validation", %{conn: conn} do
      # Without validation, the value won't be coerced to integer
      # but it won't raise a validation error either
      result =
        conn
        |> get("/without-validation?value=not-an-integer")
        |> json_response(200)

      # Value remains as string since marshalling still happens but validation is skipped
      assert %{"value" => "not-an-integer"} = result
    end
  end

  describe "with validation disabled per-parameter" do
    test "validated parameter still enforces schema", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion.*type/,
                   fn ->
                     get(conn, "/per-param-validation?validated=not-an-integer")
                   end
    end

    test "unvalidated parameter skips schema validation", %{conn: conn} do
      result =
        conn
        |> get("/per-param-validation?unvalidated=not-an-integer")
        |> json_response(200)

      assert %{"unvalidated" => "not-an-integer"} = result
    end

    test "both parameters work with valid values", %{conn: conn} do
      result =
        conn
        |> get("/per-param-validation?validated=42&unvalidated=100")
        |> json_response(200)

      assert %{"validated" => 42, "unvalidated" => 100} = result
    end
  end
end
