defmodule ApicalTest.Egress.PlugAdapterTest do
  # egress validation has to work on the Plug adapter too, which emits its
  # validators into a nested per-operation module rather than into the router.
  use ApicalTest.EndpointCase, with: Plug
  alias Plug.Conn

  use Apical.Plug.Controller

  defp json(conn, status, payload) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(status, Jason.encode!(payload))
  end

  def plugEgressConforming(conn, _params), do: json(conn, 200, %{count: 1})

  # `count` is required by the schema but absent here.
  def plugEgressNonconforming(conn, _params), do: json(conn, 200, %{wrong: "field"})

  test "a conforming response passes on the plug adapter" do
    assert %{status: 200, body: %{"count" => 1}} =
             Req.get!("http://localhost:#{@port}/conforming")
  end

  test "a nonconforming response fails on the plug adapter" do
    # the raise happens in `before_send`, so nothing of the handler's body has
    # reached the wire and the client sees a clean 500.
    assert %{status: 500} =
             Req.get!("http://localhost:#{@port}/nonconforming", retry: false)
  end
end

defmodule ApicalTest.Egress.PlugAdapterTest.Router do
  use Apical.Plug.Router

  require Apical

  Apical.router_from_string(
    """
    openapi: 3.1.0
    info:
      title: EgressPlugAdapter
      version: 1.0.0
    paths:
      "/conforming":
        get:
          operationId: plugEgressConforming
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
          operationId: plugEgressNonconforming
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
    """,
    for: Plug,
    root: "/",
    controller: ApicalTest.Egress.PlugAdapterTest,
    content_type: "application/yaml"
  )
end
