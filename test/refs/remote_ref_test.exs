defmodule ApicalTest.Refs.RemoteRefTest do
  @moduledoc """
  Tests for remote $ref resolution from cache.

  This is Issue #31: Remote refs for openapi content
  """

  use ExUnit.Case

  @cache_dir Path.expand("../fixtures/remote_refs_cache", __DIR__)

  describe "remote ref resolution from cache" do
    test "resolves schema $ref from cached file" do
      defmodule CachedSchemaRouter do
        use Phoenix.Router

        require Apical

        # The schema references a remote URL that's cached locally
        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: RemoteRefTest
            version: 1.0.0
          paths:
            "/user":
              post:
                operationId: createUser
                requestBody:
                  content:
                    "application/json":
                      schema:
                        $ref: "https://example.com/schemas/user.json#/definitions/User"
          """,
          root: "/",
          controller: ApicalTest.Refs.RemoteRefTest,
          content_type: "application/yaml",
          remote_refs_cache: unquote(@cache_dir)
        )
      end

      # If we got here, the router compiled successfully with the remote ref
      assert true
    end

    test "resolves parameter $ref from cached file" do
      defmodule CachedParameterRouter do
        use Phoenix.Router

        require Apical

        Apical.router_from_string(
          """
          openapi: 3.1.0
          info:
            title: RemoteRefTest
            version: 1.0.0
          paths:
            "/user":
              get:
                operationId: getUser
                parameters:
                  - $ref: "https://example.com/schemas/params.json#/parameters/UserId"
          """,
          root: "/",
          controller: ApicalTest.Refs.RemoteRefTest,
          content_type: "application/yaml",
          remote_refs_cache: unquote(@cache_dir)
        )
      end

      assert true
    end
  end

  describe "missing cache" do
    test "raises helpful error when remote ref not in cache" do
      assert_raise CompileError, ~r/Remote ref not found in cache/, fn ->
        defmodule MissingCacheRouter do
          use Phoenix.Router

          require Apical

          Apical.router_from_string(
            """
            openapi: 3.1.0
            info:
              title: RemoteRefTest
              version: 1.0.0
            paths:
              "/test":
                get:
                  operationId: test
                  parameters:
                    - $ref: "https://not-cached.com/missing.json"
            """,
            root: "/",
            controller: ApicalTest.Refs.RemoteRefTest,
            content_type: "application/yaml",
            remote_refs_cache: unquote(@cache_dir)
          )
        end
      end
    end

    test "raises error when remote ref used without cache configured" do
      assert_raise CompileError, ~r/remote_refs_cache/, fn ->
        defmodule NoCacheRouter do
          use Phoenix.Router

          require Apical

          Apical.router_from_string(
            """
            openapi: 3.1.0
            info:
              title: RemoteRefTest
              version: 1.0.0
            paths:
              "/test":
                get:
                  operationId: test
                  parameters:
                    - $ref: "https://example.com/schemas/test.json"
            """,
            root: "/",
            controller: ApicalTest.Refs.RemoteRefTest,
            content_type: "application/yaml"
            # No remote_refs_cache configured
          )
        end
      end
    end
  end

  # Dummy controller functions
  def createUser(conn, _params), do: Plug.Conn.send_resp(conn, 200, "ok")
  def getUser(conn, _params), do: Plug.Conn.send_resp(conn, 200, "ok")
  def test(conn, _params), do: Plug.Conn.send_resp(conn, 200, "ok")
end
