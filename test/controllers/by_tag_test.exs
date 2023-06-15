defmodule ApicalTest.Parameters.ByTagTest do
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
            tags: [tag]
            responses:
              "200":
                description: OK
        "/emptyFirst":
          get:
            operationId: emptyFirst
            tags: [empty, tag]
            responses:
              "200":
                description: OK
        "/tagFirst":
          get:
            operationId: tagFirst
            tags: [tag, empty]
            responses:
              "200":
                description: OK
        "/prioritized":
          get:
            operationId: prioritized
            tags: [tag, other]
            responses:
              "200":
                description: OK
      """,
      root: "/",
      controller: ApicalTest.Parameters.ByTagTest,
      tags: [
        tag: [controller: ApicalTest.Parameters.ByTagTest.Tagged],
        other: [controller: ApicalTest.Parameters.ByTagTest.Unimplemented]
      ],
      content_type: "application/yaml"
    )
  end

  defmodule Tagged do
    use Phoenix.Controller
    alias Plug.Conn

    for operation <- ~w(tagged emptyFirst tagFirst prioritized) do
      def unquote(:"#{operation}")(conn, _param) do
        Conn.resp(conn, 200, unquote(operation))
      end
    end
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def default(conn, _param) do
    Conn.resp(conn, 200, "default")
  end

  describe "routing forwards to correct modules" do
    for operation <- ~w(default tagged emptyFirst tagFirst prioritized) do
      test "in the #{operation} case", %{conn: conn} do
        assert %{
                 resp_body: unquote(operation),
                 status: 200
               } = get(conn, "/#{unquote(operation)}")
      end
    end
  end
end
