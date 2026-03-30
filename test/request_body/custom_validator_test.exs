defmodule ApicalTest.RequestBody.CustomValidatorTest do
  @moduledoc """
  Tests for custom request body validators.

  This is Issue #29: Custom validators for request-body
  """

  defmodule CustomValidator do
    @moduledoc "Custom validator module for testing"

    def validate_score(%{"score" => score}) when score >= 0 and score <= 100, do: :ok

    def validate_score(%{"score" => score}) do
      {:error, reason: "score must be between 0 and 100, got: #{score}"}
    end

    def validate_score(_), do: {:error, reason: "missing score field"}

    def validate_with_args(body, min, max) do
      score = body["score"]

      cond do
        is_nil(score) -> {:error, reason: "missing score field"}
        score < min -> {:error, reason: "score must be >= #{min}"}
        score > max -> {:error, reason: "score must be <= #{max}"}
        true -> :ok
      end
    end
  end

  defmodule Router do
    use Phoenix.Router

    require Apical
    alias ApicalTest.RequestBody.CustomValidatorTest.CustomValidator

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyCustomValidatorTest
        version: 1.0.0
      paths:
        "/schema-only":
          post:
            operationId: schemaOnlyValidation
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
                    properties:
                      score:
                        type: integer
        "/custom-only":
          post:
            operationId: customOnlyValidation
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
        "/custom-with-args":
          post:
            operationId: customWithArgsValidation
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
      """,
      root: "/",
      controller: ApicalTest.RequestBody.CustomValidatorTest,
      content_type: "application/yaml",
      operation_ids: [
        customOnlyValidation: [
          request_body: [
            validate: {CustomValidator, :validate_score}
          ]
        ],
        customWithArgsValidation: [
          request_body: [
            validate: {CustomValidator, :validate_with_args, [10, 90]}
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

  for operation <- ~w(schemaOnlyValidation customOnlyValidation customWithArgsValidation)a do
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

  describe "with schema-only validation (default)" do
    test "valid data passes", %{conn: conn} do
      result =
        conn
        |> do_post("/schema-only", ~s({"score": 50}))
        |> json_response(200)

      assert %{"score" => 50} = result
    end
  end

  describe "with custom validator function" do
    test "valid data passes custom validation", %{conn: conn} do
      result =
        conn
        |> do_post("/custom-only", ~s({"score": 50}))
        |> json_response(200)

      assert %{"score" => 50} = result
    end

    test "invalid data fails custom validation", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/score must be between 0 and 100/,
                   fn ->
                     do_post(conn, "/custom-only", ~s({"score": 150}))
                   end
    end

    test "missing required data fails custom validation", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/missing score field/,
                   fn ->
                     do_post(conn, "/custom-only", ~s({}))
                   end
    end
  end

  describe "with custom validator function with arguments" do
    test "valid data within custom range passes", %{conn: conn} do
      result =
        conn
        |> do_post("/custom-with-args", ~s({"score": 50}))
        |> json_response(200)

      assert %{"score" => 50} = result
    end

    test "data below custom minimum fails", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/score must be >= 10/,
                   fn ->
                     do_post(conn, "/custom-with-args", ~s({"score": 5}))
                   end
    end

    test "data above custom maximum fails", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/score must be <= 90/,
                   fn ->
                     do_post(conn, "/custom-with-args", ~s({"score": 95}))
                   end
    end
  end
end
