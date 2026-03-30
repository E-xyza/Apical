defmodule ApicalTest.RequestBody.PropertyValidatorTest do
  @moduledoc """
  Tests for custom property validators within request bodies.

  This is Issue #51: Custom validators for properties
  """

  defmodule PropertyValidator do
    @moduledoc "Custom property validator module for testing"

    def validate_email(email) when is_binary(email) do
      if String.contains?(email, "@") do
        :ok
      else
        {:error, reason: "invalid email format"}
      end
    end

    def validate_email(_), do: {:error, reason: "email must be a string"}

    def validate_age(age) when is_integer(age) and age >= 0 and age <= 150, do: :ok
    def validate_age(_), do: {:error, reason: "age must be between 0 and 150"}

    def validate_with_args(value, min, max) when is_integer(value) do
      cond do
        value < min -> {:error, reason: "value must be >= #{min}"}
        value > max -> {:error, reason: "value must be <= #{max}"}
        true -> :ok
      end
    end

    def validate_with_args(_, _, _), do: {:error, reason: "value must be an integer"}
  end

  defmodule Router do
    use Phoenix.Router

    require Apical
    alias ApicalTest.RequestBody.PropertyValidatorTest.PropertyValidator

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: PropertyValidatorTest
        version: 1.0.0
      paths:
        "/with-property-validators":
          post:
            operationId: withPropertyValidators
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
                    properties:
                      email:
                        type: string
                      age:
                        type: integer
                      score:
                        type: integer
      """,
      root: "/",
      controller: ApicalTest.RequestBody.PropertyValidatorTest,
      content_type: "application/yaml",
      operation_ids: [
        withPropertyValidators: [
          request_body: [
            properties: [
              email: [validate: {PropertyValidator, :validate_email}],
              age: [validate: {PropertyValidator, :validate_age}],
              score: [validate: {PropertyValidator, :validate_with_args, [0, 100]}]
            ]
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

  def withPropertyValidators(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  defp do_post(conn, route, payload) do
    content_length = byte_size(payload)

    conn
    |> Conn.put_req_header("content-length", "#{content_length}")
    |> Conn.put_req_header("content-type", "application/json")
    |> post(route, payload)
  end

  describe "with property validators" do
    test "all valid properties pass", %{conn: conn} do
      result =
        conn
        |> do_post(
          "/with-property-validators",
          ~s({"email": "user@example.com", "age": 25, "score": 50})
        )
        |> json_response(200)

      assert %{"email" => "user@example.com", "age" => 25, "score" => 50} = result
    end

    test "invalid email fails property validation", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/invalid email format/,
                   fn ->
                     do_post(
                       conn,
                       "/with-property-validators",
                       ~s({"email": "invalid-email", "age": 25, "score": 50})
                     )
                   end
    end

    test "invalid age fails property validation", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/age must be between 0 and 150/,
                   fn ->
                     do_post(
                       conn,
                       "/with-property-validators",
                       ~s({"email": "user@example.com", "age": 200, "score": 50})
                     )
                   end
    end

    test "score outside custom range fails", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/value must be <= 100/,
                   fn ->
                     do_post(
                       conn,
                       "/with-property-validators",
                       ~s({"email": "user@example.com", "age": 25, "score": 150})
                     )
                   end
    end

    test "missing properties with validators pass (optional)", %{conn: conn} do
      # Properties without values should not be validated
      result =
        conn
        |> do_post("/with-property-validators", ~s({}))
        |> json_response(200)

      assert %{} = result
    end
  end
end
