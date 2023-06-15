defmodule ApicalTest.Parameters.ByOperationIdTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestGet
        version: 1.0.0
      paths:
        "/default":
          get:
            operationId: default
            responses:
              "200":
                description: OK
        "/tagged":
          get:
            operationId: tagged
            responses:
              "200":
                description: OK
        "/untagged":
          get:
            operationId: untagged
            responses:
              "200":
                description: OK
      """,
      root: "/",
      controller: [
        ApicalTest.Parameters.ByOperationIdTest,
        by_operation_id: [
          tagged: ApicalTest.Parameters.ByOperationIdTest.OperationId,
          untagged: ApicalTest.Parameters.ByOperationIdTest.OperationId
        ],
        by_tag: [
          tagged: ApicalTest.Parameters.ByOperationIdTest.Tagged
        ]
      ],
      content_type: "application/yaml"
    )
  end

  defmodule OperationId do
    use Phoenix.Controller
    alias Plug.Conn

    def tagged(conn, _param) do
      Conn.resp(conn, 200, "tagged")
    end

    def untagged(conn, _param) do
      Conn.resp(conn, 200, "untagged")
    end
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def default(conn, _param) do
    Conn.resp(conn, 200, "default")
  end

  describe "routing forwards to correct modules" do
    test "in the default case", %{conn: conn} do
      assert %{
               resp_body: "default",
               status: 200
             } = get(conn, "/default")
    end

    test "when the operationId is tagged operationId takes precedence", %{conn: conn} do
      assert %{
               resp_body: "tagged",
               status: 200
             } = get(conn, "/tagged")
    end

    test "when the operationId is untagged", %{conn: conn} do
      assert %{
               resp_body: "untagged",
               status: 200
             } = get(conn, "/untagged")
    end
  end
end
