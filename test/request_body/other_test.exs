defmodule ApicalTest.RequestBody.OtherTest do
  defmodule GenericSource do
    @behaviour Apical.Plugs.RequestBody.Source
    alias Plug.Conn

    @impl true
    def fetch(conn, opts) do
      response = Keyword.get(opts, :tag, "generic")

      {:ok, Conn.put_private(conn, :response, response)}
    end

    @impl true
    def validate!(_, _), do: :ok
  end

  defmodule Router do
    use Phoenix.Router

    require Apical
    alias ApicalTest.RequestBody.OtherTest.GenericSource

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyOtherTest
        version: 1.0.0
      paths:
        "/no-parser":
          post:
            operationId: requestBodyNoParser
            requestBody:
              content:
                "text/csv": {}
        "/multi-parser":
          post:
            operationId: requestBodyMultiParser
            requestBody:
              content:
                "*/*": {}
                "application/*": {}
                "application/x-foo": {}
                "application/x-foo; charset=utf-8": {}
        "/tag-parser":
          post:
            operationId: requestBodyTagParser
            tags: [tag]
            requestBody:
              content:
                "application/*": {}
                "application/x-foo": {}
        "/operation-parser":
          post:
            operationId: requestBodyOperationParser
            tags: [tag]
            requestBody:
              content:
                "application/*": {}
                "application/x-foo": {}
      """,
      root: "/",
      controller: ApicalTest.RequestBody.OtherTest,
      content_type: "application/yaml",
      content_sources: [
        {"*/*", GenericSource},
        {"application/*", {GenericSource, tag: "application generic"}},
        {"application/x-foo", {GenericSource, tag: "application specific"}},
        {"application/x-foo; charset=utf-8", {GenericSource, tag: "application option"}}
      ],
      tags: [
        tag: [
          content_sources: [{"application/*", {GenericSource, tag: "application tagged"}}]
        ]
      ],
      operation_ids: [
        requestBodyOperationParser: [
          content_sources: [{"application/*", {GenericSource, tag: "application operation_id"}}]
        ]
      ]
    )
  end

  use ApicalTest.EndpointCase

  alias Plug.Conn

  def requestBodyNoParser(conn, _params) do
    [content_type] = Conn.get_req_header(conn, "content-type")

    {:ok, body, conn} = Conn.read_body(conn)

    conn
    |> Conn.put_resp_content_type(content_type)
    |> Conn.send_resp(200, body)
  end

  for operation <- ~w(requestBodyMultiParser requestBodyTagParser requestBodyOperationParser)a do
    def unquote(operation)(conn, _params) do
      conn
      |> Conn.put_resp_content_type("text/plain")
      |> Conn.send_resp(200, conn.private.response)

      # note that conn.private.response comes from GenericSource
    end
  end

  defp do_post(conn, route, payload, content_type) do
    conn
    |> Conn.put_req_header("content-type", content_type)
    |> post(route, payload)
    |> Map.get(:resp_body)
  end

  describe "for posted object data" do
    test "it incorporates into params", %{conn: conn} do
      assert "foo" = do_post(conn, "/no-parser", "foo", "text/csv")
    end
  end

  describe "when multiple content-types are declared" do
    test "the fully generic content-type is accepted when it doesn't match", %{conn: conn} do
      assert "generic" = do_post(conn, "/multi-parser", "foo", "text/csv")
    end

    test "the content-supertype can be selected when the subtype doesn't match", %{conn: conn} do
      assert "application generic" = do_post(conn, "/multi-parser", "foo", "application/x-bar")
    end

    test "the content-subtype overrides generic matches", %{conn: conn} do
      assert "application specific" = do_post(conn, "/multi-parser", "foo", "application/x-foo")
    end

    test "the content-subtype with option overrides generic matches", %{conn: conn} do
      assert "application option" = do_post(conn, "/multi-parser", "foo", "application/x-foo; charset=utf-8")
    end
  end

  describe "when content-type is declared by tag" do
    test "the fully generic content-type is accepted when it doesn't match", %{conn: conn} do
      assert "application specific" = do_post(conn, "/tag-parser", "foo", "application/x-foo")
    end

    test "the content-subtype with option overrides generic matches", %{conn: conn} do
      assert "application tagged" = do_post(conn, "/tag-parser", "foo", "application/x-bar")
    end
  end

  describe "when content-type is declared by operation_id" do
    test "the fully generic conent-type is accepted when it doesn't match", %{conn: conn} do
      assert "application specific" = do_post(conn, "/operation-parser", "foo", "application/x-foo")
    end

    test "the content-subtype with option overrides generic matches", %{conn: conn} do
      assert "application operation_id" = do_post(conn, "/operation-parser", "foo", "application/x-bar")
    end
  end
end
