defmodule ApicalTest.RequestBody.MarshalTest do
  @moduledoc """
  Tests for request body marshalling - converting string values from form-encoded
  requests to proper types based on the schema.

  This is Issue #53: Refactor request body to marshalling step.
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyMarshalTest
        version: 1.0.0
      paths:
        "/form-with-types":
          post:
            operationId: formWithTypes
            requestBody:
              content:
                "application/x-www-form-urlencoded":
                  schema:
                    type: object
                    properties:
                      count:
                        type: integer
                      price:
                        type: number
                      active:
                        type: boolean
                      name:
                        type: string
        "/form-with-nested":
          post:
            operationId: formWithNested
            requestBody:
              content:
                "application/x-www-form-urlencoded":
                  schema:
                    type: object
                    properties:
                      user:
                        type: object
                        properties:
                          age:
                            type: integer
                          verified:
                            type: boolean
        "/form-with-array":
          post:
            operationId: formWithArray
            requestBody:
              content:
                "application/x-www-form-urlencoded":
                  schema:
                    type: object
                    properties:
                      ids:
                        type: array
                        items:
                          type: integer
        "/form-validation-after-marshal":
          post:
            operationId: formValidationAfterMarshal
            requestBody:
              content:
                "application/x-www-form-urlencoded":
                  schema:
                    type: object
                    properties:
                      score:
                        type: integer
                        minimum: 0
                        maximum: 100
      """,
      root: "/",
      controller: ApicalTest.RequestBody.MarshalTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase

  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for operation <- ~w(formWithTypes formWithNested formWithArray formValidationAfterMarshal)a do
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
    |> Conn.put_req_header("content-type", "application/x-www-form-urlencoded")
    |> post(route, payload)
  end

  describe "form-encoded request body marshalling" do
    test "marshals integer properties", %{conn: conn} do
      result =
        conn
        |> do_post("/form-with-types", "count=42")
        |> json_response(200)

      # Without marshalling, count would be "42" (string)
      # With marshalling, it should be 42 (integer)
      assert %{"count" => 42} = result
      assert is_integer(result["count"])
    end

    test "marshals number properties", %{conn: conn} do
      result =
        conn
        |> do_post("/form-with-types", "price=19.99")
        |> json_response(200)

      assert %{"price" => 19.99} = result
      assert is_float(result["price"])
    end

    test "marshals boolean properties", %{conn: conn} do
      result =
        conn
        |> do_post("/form-with-types", "active=true")
        |> json_response(200)

      assert %{"active" => true} = result
      assert is_boolean(result["active"])

      result =
        conn
        |> do_post("/form-with-types", "active=false")
        |> json_response(200)

      assert %{"active" => false} = result
    end

    test "keeps string properties as strings", %{conn: conn} do
      result =
        conn
        |> do_post("/form-with-types", "name=Alice")
        |> json_response(200)

      assert %{"name" => "Alice"} = result
      assert is_binary(result["name"])
    end

    test "marshals multiple properties in one request", %{conn: conn} do
      result =
        conn
        |> do_post("/form-with-types", "count=5&price=9.99&active=true&name=Test")
        |> json_response(200)

      assert %{
               "count" => 5,
               "price" => 9.99,
               "active" => true,
               "name" => "Test"
             } = result

      assert is_integer(result["count"])
      assert is_float(result["price"])
      assert is_boolean(result["active"])
      assert is_binary(result["name"])
    end
  end

  describe "nested object marshalling" do
    test "marshals nested object properties", %{conn: conn} do
      result =
        conn
        |> do_post("/form-with-nested", "user[age]=25&user[verified]=true")
        |> json_response(200)

      assert %{"user" => %{"age" => 25, "verified" => true}} = result
      assert is_integer(result["user"]["age"])
      assert is_boolean(result["user"]["verified"])
    end
  end

  describe "array marshalling" do
    test "marshals array items", %{conn: conn} do
      result =
        conn
        |> do_post("/form-with-array", "ids[]=1&ids[]=2&ids[]=3")
        |> json_response(200)

      assert %{"ids" => [1, 2, 3]} = result
      assert Enum.all?(result["ids"], &is_integer/1)
    end
  end

  describe "validation after marshalling" do
    test "validates against proper types after marshalling", %{conn: conn} do
      # Valid: score is 50, within 0-100 range
      result =
        conn
        |> do_post("/form-validation-after-marshal", "score=50")
        |> json_response(200)

      assert %{"score" => 50} = result
    end

    test "rejects values outside schema constraints", %{conn: conn} do
      # Invalid: score is 150, above maximum of 100
      assert_raise ParameterError,
                   ~r/fails schema criterion.*maximum/,
                   fn ->
                     do_post(conn, "/form-validation-after-marshal", "score=150")
                   end
    end

    test "rejects non-integer values for integer schema", %{conn: conn} do
      # Invalid: "abc" cannot be marshalled to integer
      assert_raise ParameterError,
                   ~r/fails schema criterion.*type/,
                   fn ->
                     do_post(conn, "/form-validation-after-marshal", "score=abc")
                   end
    end
  end
end
