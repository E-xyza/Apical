defmodule ApicalTest.RequestBody.OtherTest do
  defmodule GenericSource do
    @behaviour Apical.Plugs.RequestBody.Source
    alias Plug.Conn

    @impl true
    def fetch(conn, _, opts) do
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

  alias Apical.Exceptions.InvalidContentTypeError
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
    |> Conn.put_req_header("content-length", "#{byte_size(payload)}")
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
      assert "application option" =
               do_post(conn, "/multi-parser", "foo", "application/x-foo; charset=utf-8")
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
      assert "application specific" =
               do_post(conn, "/operation-parser", "foo", "application/x-foo")
    end

    test "the content-subtype with option overrides generic matches", %{conn: conn} do
      assert "application operation_id" =
               do_post(conn, "/operation-parser", "foo", "application/x-bar")
    end
  end

  @payload "foo,bar"
  @payload_length byte_size(@payload)

  alias Apical.Exceptions.MissingContentTypeError
  alias Apical.Exceptions.MultipleContentTypeError
  alias Apical.Exceptions.InvalidContentTypeError

  alias Apical.Exceptions.MissingContentLengthError
  alias Apical.Exceptions.MultipleContentLengthError
  alias Apical.Exceptions.InvalidContentLengthError

  defp manual_call(conn) do
    # we have to do this manually since dispatch/5 doesn't let us have fun
    conn
    |> Plug.Adapters.Test.Conn.conn(:post, "/no-parser", @payload)
    |> @endpoint.call(@endpoint.init([]))
  end

  test "generic missing content-type error", %{conn: conn} do
    assert_raise MissingContentTypeError, fn ->
      conn
      |> Conn.put_req_header("content-length", "#{@payload_length}")
      |> manual_call
    end
  end

  test "duplicate content-type error", %{conn: conn} do
    assert_raise MultipleContentTypeError, fn ->
      # we have to do this manually since dispatch/5 doesn't let us have fun
      conn
      |> Map.update!(
        :req_headers,
        &[{"content-type", "text/csv"}, {"content-type", "text/csv"} | &1]
      )
      |> Conn.put_req_header("content-length", "#{@payload_length}")
      |> manual_call
    end
  end

  test "invalid content-type error", %{conn: conn} do
    assert_raise InvalidContentTypeError, fn ->
      do_post(conn, "/no-parser", @payload, "this-is-not-a-content-type")
    end
  end

  test "generic missing content-length error", %{conn: conn} do
    assert_raise MissingContentLengthError, fn ->
      # we have to do this manually since dispatch/5 doesn't let us have fun
      conn
      |> Conn.put_req_header("content-type", "text/csv")
      |> manual_call
    end
  end

  test "generic multiple content-length error", %{conn: conn} do
    assert_raise MultipleContentLengthError, fn ->
      # we have to do this manually since dispatch/5 doesn't let us have fun
      conn
      |> Conn.put_req_header("content-type", "text/csv")
      |> Map.update!(
        :req_headers,
        &[{"content-length", "#{@payload_length}"}, {"content-length", "#{@payload_length}"} | &1]
      )
      |> manual_call
    end
  end

  test "generic invalid content-length error", %{conn: conn} do
    assert_raise InvalidContentLengthError,
                 "invalid content-length header provided: not-a-number",
                 fn ->
                   # we have to do this manually since dispatch/5 doesn't let us have fun
                   conn
                   |> Conn.put_req_header("content-type", "text/csv")
                   |> Conn.put_req_header("content-length", "not-a-number")
                   |> manual_call
                 end
  end
end
