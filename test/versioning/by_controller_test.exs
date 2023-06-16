defmodule ApicalTest.Versioning.ByControllerTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: VersioningByControllerTest
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
      operation_ids: [
        sharedOp: [controller: ApicalTest.Versioning.ByControllerTest.SharedController],
        forkedOp: [controller: ApicalTest.Versioning.ByControllerTest.V1.Controller]
      ],
      content_type: "application/yaml"
    )

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: VersioningByControllerTest
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
      operation_ids: [
        sharedOp: [controller: ApicalTest.Versioning.ByControllerTest.SharedController],
        forkedOp: [controller: ApicalTest.Versioning.ByControllerTest.V2.Controller]
      ],
      content_type: "application/yaml"
    )
  end

  defmodule SharedController do
    use Phoenix.Controller
    alias Plug.Conn

    def sharedOp(conn, _param) do
      Conn.resp(conn, 200, "shared")
    end
  end

  defmodule V1.Controller do
    use Phoenix.Controller
    alias Plug.Conn

    def forkedOp(conn, _param) do
      Conn.resp(conn, 200, "v1")
    end
  end

  defmodule V2.Controller do
    use Phoenix.Controller
    alias Plug.Conn

    def forkedOp(conn, _param) do
      Conn.resp(conn, 200, "v2")
    end
  end

  use ApicalTest.EndpointCase

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
