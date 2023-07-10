defmodule ApicalTest.Parameters.ByGroupTest do
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
        "/grouped":
          get:
            operationId: grouped
            responses:
              "200":
                description: OK
        "/tagged":
          get:
            operationId: tagged
            tags: [tag]
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
      controller: ApicalTest.Parameters.ByGroupTest,
      operation_ids: [
        tagged: [controller: ApicalTest.Parameters.ByGroupTest.OperationId],
        untagged: [controller: ApicalTest.Parameters.ByGroupTest.OperationId]
      ],
      groups: [
        [:grouped, controller: ApicalTest.Parameters.ByGroupTest.OperationId]
      ],
      tags: [
        tag: [controller: ApicalTest.Parameters.ByGroupTest.Unimplemented]
      ],
      encoding: "application/yaml"
    )
  end

  defmodule OperationId do
    use Phoenix.Controller
    alias Plug.Conn

    for operation <- ~w(tagged untagged grouped) do
      def unquote(:"#{operation}")(conn, _param) do
        Conn.resp(conn, 200, unquote(operation))
      end
    end
  end

  use ApicalTest.EndpointCase
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

    test "when the operationId is grouped grouped takes precedence over global", %{conn: conn} do
      assert %{
               resp_body: "grouped",
               status: 200
             } = get(conn, "/grouped")
    end

    test "when the operationId is untagged", %{conn: conn} do
      assert %{
               resp_body: "untagged",
               status: 200
             } = get(conn, "/untagged")
    end
  end
end
