defmodule ApicalTest.Accept.DisabledTest do
  defmodule GlobalDisabledRouter do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: AcceptDisabledGlobalTest
        version: 1.0.0
      paths:
        "/json-only":
          get:
            operationId: jsonOnly
            responses:
              "200":
                description: JSON response
                content:
                  application/json:
                    schema:
                      type: object
      """,
      root: "/",
      controller: ApicalTest.Accept.DisabledTest,
      validate_accept: false,
      content_type: "application/yaml"
    )
  end

  defmodule OperationDisabledRouter do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: AcceptDisabledOperationTest
        version: 1.0.0
      paths:
        "/disabled":
          get:
            operationId: disabledAccept
            responses:
              "200":
                description: JSON response
                content:
                  application/json:
                    schema:
                      type: object
        "/enabled":
          get:
            operationId: enabledAccept
            responses:
              "200":
                description: JSON response
                content:
                  application/json:
                    schema:
                      type: object
      """,
      root: "/",
      controller: ApicalTest.Accept.DisabledTest,
      operation_ids: [
        disabledAccept: [validate_accept: false]
      ],
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase

  defmodule GlobalEndpoint do
    use Phoenix.Endpoint, otp_app: :apical
    plug(ApicalTest.Accept.DisabledTest.GlobalDisabledRouter)
  end

  defmodule OperationEndpoint do
    use Phoenix.Endpoint, otp_app: :apical
    plug(ApicalTest.Accept.DisabledTest.OperationDisabledRouter)
  end

  use ExUnit.Case
  use Phoenix.Controller, formats: [:json]
  import Phoenix.ConnTest
  alias Plug.Conn
  alias Apical.Exceptions.NotAcceptableError

  @endpoint GlobalEndpoint

  setup_all do
    Application.put_env(:apical, GlobalEndpoint, adapter: Bandit.PhoenixAdapter)
    Application.put_env(:apical, OperationEndpoint, adapter: Bandit.PhoenixAdapter)
    GlobalEndpoint.start_link()
    OperationEndpoint.start_link()
    :ok
  end

  setup do
    %{conn: build_conn()}
  end

  for operation <- ~w(jsonOnly disabledAccept enabledAccept)a do
    def unquote(operation)(conn, _params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(%{ok: true}))
    end
  end

  describe "validate_accept: false globally" do
    @endpoint GlobalEndpoint

    test "allows any Accept header when globally disabled", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "text/html")
        |> get("/json-only")

      assert %{"ok" => true} = json_response(response, 200)
    end
  end

  describe "validate_accept: false per operation" do
    @endpoint OperationEndpoint

    test "allows any Accept header when disabled for specific operation", %{conn: conn} do
      response =
        conn
        |> Plug.Conn.put_req_header("accept", "text/html")
        |> get("/disabled")

      assert %{"ok" => true} = json_response(response, 200)
    end

    test "still validates Accept header for other operations", %{conn: conn} do
      assert_raise NotAcceptableError,
                   ~r/Accept header `text\/html` does not match available content types/,
                   fn ->
                     conn
                     |> Plug.Conn.put_req_header("accept", "text/html")
                     |> get("/enabled")
                   end
    end
  end
end
