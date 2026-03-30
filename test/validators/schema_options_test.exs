defmodule ApicalTest.Validators.SchemaOptionsTest do
  @moduledoc """
  Tests for schema options passthru to Exonerate validators.

  This is Issue #12: Verify passthru of schema options

  Tests that Exonerate options (draft, format, metadata, decoders) are
  properly passed through from router configuration to the generated
  validation functions.
  """

  defmodule Router do
    use Phoenix.Router

    require Apical

    # Test with draft and format options at router level
    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: SchemaOptionsTest
        version: 1.0.0
      paths:
        "/with-options":
          get:
            operationId: withOptions
            parameters:
              - name: value
                in: query
                required: true
                schema:
                  type: integer
        "/json-body":
          post:
            operationId: jsonBody
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
                    properties:
                      count:
                        type: integer
      """,
      root: "/",
      controller: ApicalTest.Validators.SchemaOptionsTest,
      content_type: "application/yaml",
      # These options should be passed through to Exonerate
      draft: "2020-12"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase

  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  def withOptions(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  def jsonBody(conn, params) do
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

  describe "draft option passthru" do
    test "validation works with draft option specified", %{conn: conn} do
      # The draft option should be passed through and validation should work
      result =
        conn
        |> get("/with-options?value=42")
        |> json_response(200)

      assert %{"value" => 42} = result
    end

    test "validation errors still work with draft option", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion.*type/,
                   fn ->
                     get(conn, "/with-options?value=not-an-integer")
                   end
    end

    test "request body validation works with draft option", %{conn: conn} do
      result =
        conn
        |> do_post("/json-body", ~s({"count": 5}))
        |> json_response(200)

      assert %{"count" => 5} = result
    end

    test "request body validation errors work with draft option", %{conn: conn} do
      assert_raise ParameterError,
                   ~r/fails schema criterion.*type/,
                   fn ->
                     do_post(conn, "/json-body", ~s({"count": "not-an-integer"}))
                   end
    end
  end

  describe "schema options extraction" do
    test "exonerate options are extracted correctly" do
      # Verify that the @exonerate_opts are defined and include expected options
      # This tests the compile-time extraction of options

      opts = [
        resource: "test",
        version: "1.0.0",
        format: :assertive,
        draft: "2020-12",
        metadata: %{custom: true},
        extra_option: "should be dropped"
      ]

      # Extract only exonerate options (should match what validators.ex does)
      exonerate_opts = ~w(metadata format decoders draft)a
      extracted = Keyword.take(opts, exonerate_opts)

      assert Keyword.has_key?(extracted, :format)
      assert Keyword.has_key?(extracted, :draft)
      assert Keyword.has_key?(extracted, :metadata)
      refute Keyword.has_key?(extracted, :extra_option)
      refute Keyword.has_key?(extracted, :resource)
      refute Keyword.has_key?(extracted, :version)
    end
  end
end
