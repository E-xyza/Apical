defmodule ApicalTest.EvalTest do
  # `router_from_string(..., eval: true)` evaluates the spec expression at compile
  # time in the caller's context, so the document can be COMPOSED from string
  # literals and helper-module function calls. The resolved string is also stashed on
  # the router as `@apical_spec_string` so it can be served/introspected at runtime.

  # A helper module (separate, already compiled) that contributes path fragments —
  # the "compose the spec from parts" use case.
  defmodule Fragments do
    def paths do
      for {op, path} <- [{"ping", "/ping"}, {"pong", "/pong"}], into: "" do
        """
          #{path}:
            get:
              operationId: #{op}
              responses:
                "200":
                  description: ok
        """
      end
    end
  end

  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: Eval Test
        version: 1.0.0
      paths:
      #{ApicalTest.EvalTest.Fragments.paths()}
      """,
      eval: true,
      root: "/",
      controller: ApicalTest.EvalTest,
      content_type: "application/yaml"
    )

    def spec, do: @apical_spec_string
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def ping(conn, _params), do: Conn.send_resp(conn, 200, "PING")
  def pong(conn, _params), do: Conn.send_resp(conn, 200, "PONG")

  test "routes composed from a helper module are dispatched", %{conn: conn} do
    assert "PING" = conn |> get("/ping") |> response(200)
    assert "PONG" = conn |> get("/pong") |> response(200)
  end

  test "the resolved spec is stashed as @apical_spec_string" do
    spec = Router.spec()
    assert is_binary(spec)
    assert spec =~ "openapi: 3.1.0"
    assert spec =~ "operationId: pong"
  end
end
