defmodule ApicalTest.Versioning.ByDifferentRoutersTest do
  defmodule Router1 do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: VersioningByDifferentRoutersTest
        version: 1.0.0
      paths:
        "/shared":
          get:
            operationId: sharedOp
            responses:
              "200":
                description: OK
        "/forked":
          get:
            operationId: forkedOp
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Versioning.ByDifferentRoutersTest,
      content_type: "application/yaml",
      root: "/"
    )
  end

  defmodule Router2 do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: VersioningByDifferentRoutersTest
        version: 2.0.0
      paths:
        "/shared":
          get:
            operationId: sharedOp
            responses:
              "200":
                description: OK
        "/forked":
          get:
            operationId: forkedOp
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Versioning.ByDifferentRoutersTest,
      content_type: "application/yaml",
      root: "/"
    )
  end

  defmodule Router do
    use Phoenix.Router

    scope "/" do
      forward("/v1", Router1)
    end

    scope "/" do
      forward("/v2", Router2)
    end
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def sharedOp(conn, _param) do
    Conn.resp(conn, 200, "shared")
  end

  def forkedOp(conn = %{assigns: %{api_version: "1.0.0"}}, _param) do
    Conn.resp(conn, 200, "v1")
  end

  def forkedOp(conn = %{assigns: %{api_version: "2.0.0"}}, _param) do
    Conn.resp(conn, 200, "v2")
  end

  describe "for shared routes" do
    test "v1 routes to shared", %{conn: conn} do
      assert %{
               resp_body: "shared",
               status: 200
             } = get(conn, "/v1/shared")
    end

    test "v2 routes to shared", %{conn: conn} do
      assert %{
               resp_body: "shared",
               status: 200
             } = get(conn, "/v2/shared")
    end
  end

  describe "for forked routes" do
    test "v1 routes to forked", %{conn: conn} do
      assert %{
               resp_body: "v1",
               status: 200
             } = get(conn, "/v1/forked")
    end

    test "v2 routes to shared", %{conn: conn} do
      assert %{
               resp_body: "v2",
               status: 200
             } = get(conn, "/v2/forked")
    end
  end
end
