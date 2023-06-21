defmodule ApicalTest.RequestBody.FormEncodedTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyFormEncodedTest
        version: 1.0.0
      paths:
        "/object":
          post:
            operationId: requestBodyFormEncodedObject
            requestBody:
              content:
                "application/x-www-form-urlencoded":
                  schema:
                    type: object
      """,
      root: "/",
      controller: ApicalTest.RequestBody.FormEncodedTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase

  alias ApicalTest.RequestBody.FormEncodedTest.Endpoint
  alias Plug.Parsers.UnsupportedMediaTypeError
  alias Plug.Conn

  for operation <-
        ~w(requestBodyFormEncodedObject requestBodyFormEncodedArray requestBodyGeneric nest_all_json)a do
    def unquote(operation)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  defp do_post(conn, route, payload, content_type \\ "application/x-www-form-urlencoded") do
    content_length = byte_size(payload)

    conn
    |> Conn.put_req_header("content-length", "#{content_length}")
    |> Conn.put_req_header("content-type", content_type)
    |> post(route, payload)
  end

  describe "for posted object data" do
    test "it incorporates into params", %{conn: conn} do
      assert %{"foo" => "bar"} =
               conn
               |> do_post("/object", "foo=bar")
               |> json_response(200)

      assert %{"foo" => "bar", "baz" => "quux"} =
               conn
               |> do_post("/object", "foo=bar&baz=quux")
               |> json_response(200)
    end
  end

  describe "generic errors when posting" do
    # TODO: create a more meaningful apical error for this
    test "passing data with the wrong content-type", %{conn: conn} do
      assert_raise UnsupportedMediaTypeError,
                   "unsupported media type text/csv",
                   fn ->
                     do_post(conn, "/object", "", "text/csv")
                   end
    end

    test "passing data with no content-type", %{conn: conn} do
      assert %{plug_status: 400} = %Apical.Exceptions.MissingContentTypeError{}

      assert_raise Apical.Exceptions.MissingContentTypeError, "missing content-type header", fn ->
        conn
        |> Plug.Adapters.Test.Conn.conn(:post, "/object", "{}")
        |> Endpoint.call(Endpoint.init([]))
      end
    end
  end
end
