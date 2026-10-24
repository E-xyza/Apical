defmodule ApicalTest.Egress.EgressTest do
  use ExUnit.Case, async: true

  defmodule Router do
    use Phoenix.Router
    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: Egress Test
        version: 1.0.0
      paths:
        "/conforming":
          get:
            operationId: egressConforming
            responses:
              "200":
                description: OK
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        count:
                          type: integer
                      required: [count]
        "/nonconforming":
          get:
            operationId: egressNonconforming
            responses:
              "200":
                description: OK
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        count:
                          type: integer
                      required: [count]
        "/wrong-type":
          get:
            operationId: egressWrongType
            responses:
              "200":
                description: OK
                content:
                  application/json:
                    schema:
                      type: array
        "/no-schema":
          get:
            operationId: egressNoSchema
            responses:
              "200":
                description: OK
                content:
                  application/json: {}
        "/by-status":
          get:
            operationId: egressByStatus
            responses:
              "201":
                description: Created
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        id:
                          type: string
                      required: [id]
        "/not-json":
          get:
            operationId: egressNotJson
            responses:
              "200":
                description: OK
                content:
                  text/plain:
                    schema:
                      type: string
      """,
      root: "/",
      controller: ApicalTest.Egress.EgressTest,
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase

  alias Apical.Exceptions.EgressError
  alias Plug.Conn

  defp json(conn, status, payload) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(status, Jason.encode!(payload))
  end

  def egressConforming(conn, _params), do: json(conn, 200, %{count: 1})

  # `count` is required by the schema but absent here.
  def egressNonconforming(conn, _params), do: json(conn, 200, %{wrong: "field"})

  # the schema says array, this sends an object.
  def egressWrongType(conn, _params), do: json(conn, 200, %{not: "an array"})

  def egressNoSchema(conn, _params), do: json(conn, 200, %{anything: "goes"})

  def egressByStatus(conn, _params), do: json(conn, 201, %{id: "abc"})

  def egressNotJson(conn, _params) do
    conn
    |> Conn.put_resp_content_type("text/plain")
    |> Conn.send_resp(200, "plain text body")
  end

  describe "when egress testing is enabled" do
    test "a conforming response passes through", %{conn: conn} do
      assert %{"count" => 1} =
               conn
               |> get("/conforming")
               |> json_response(200)
    end

    test "a response missing a required property raises", %{conn: conn} do
      assert_raise EgressError, fn ->
        get(conn, "/nonconforming")
      end
    end

    test "a response of the wrong type raises", %{conn: conn} do
      assert_raise EgressError, fn ->
        get(conn, "/wrong-type")
      end
    end

    test "the error carries a 500 status, not a 4xx", %{conn: conn} do
      error =
        assert_raise EgressError, fn ->
          get(conn, "/nonconforming")
        end

      assert error.plug_status == 500
      assert Plug.Exception.status(error) == 500
    end

    test "the error names the operation, status and media type", %{conn: conn} do
      error =
        assert_raise EgressError, fn ->
          get(conn, "/nonconforming")
        end

      message = Exception.message(error)
      assert message =~ "egressNonconforming"
      assert message =~ "200"
      assert message =~ "application/json"
    end

    test "a response with no schema is not validated", %{conn: conn} do
      assert %{"anything" => "goes"} =
               conn
               |> get("/no-schema")
               |> json_response(200)
    end

    test "validators are selected by status code", %{conn: conn} do
      assert %{"id" => "abc"} =
               conn
               |> get("/by-status")
               |> json_response(201)
    end

    test "a non-JSON body is passed through", %{conn: conn} do
      assert "plain text body" =
               conn
               |> get("/not-json")
               |> response(200)
    end
  end
end
