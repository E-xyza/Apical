defmodule ApicalTest.Plug.RequestBodyResourceTest do
  # Regression: an operation with a requestBody schema generates body validators
  # that call `Exonerate.function_from_resource(..., resource)`. In the Plug
  # adapter those validators are emitted inside the operation's nested defmodule,
  # but `Exonerate.register_resource/3` runs in the parent router module. Because
  # Exonerate's resource cache is per-compiling-module, the nested module could not
  # find the registered resource ("resource ... not found in cache") at compile
  # time. This router only compiles if the resource is visible in the operation
  # module's scope.
  use ApicalTest.EndpointCase, with: Plug
  alias Plug.Conn

  use Apical.Plug.Controller

  def postBody(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "a valid body passes the generated validator (compiles + resolves resource)" do
    assert %{status: 200, body: "OK"} =
             Req.post!("http://localhost:#{@port}/", json: %{"name" => "widget"})
  end

  test "an invalid body is rejected by the generated validator" do
    assert %{status: 400} =
             Req.post!("http://localhost:#{@port}/", json: %{"name" => 123})
  end
end

defmodule ApicalTest.Plug.RequestBodyResourceTest.Router do
  use Apical.Plug.Router

  require Apical

  Apical.router_from_string(
    """
    openapi: 3.1.0
    info:
      title: RequestBodyResource
      version: 1.0.0
    paths:
      "/":
        post:
          operationId: postBody
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  type: object
                  properties:
                    name:
                      type: string
                  required:
                    - name
          responses:
            "200":
              description: OK
    """,
    for: Plug,
    root: "/",
    controller: ApicalTest.Plug.RequestBodyResourceTest,
    content_type: "application/yaml"
  )
end
