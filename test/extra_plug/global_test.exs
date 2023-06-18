defmodule ApicalTest.ExtraPlug.GlobalTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    alias Plug.Conn

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: GlobalTest
        version: 1.0.0
      paths:
        "/global":
          get:
            operationId: global
            responses:
              "200":
                description: OK
      """,
      root: "/",
      controller: ApicalTest.ExtraPlug.GlobalTest,
      extra_plugs: [
        :local_plug,
        {:local_plug, ["local option"]},
        ApicalTest.ExtraPlug,
        {ApicalTest.ExtraPlug, ["module option"]}
      ],
      content_type: "application/yaml"
    )

    def local_plug(conn, []) do
      Conn.put_private(conn, :extra_local_plug, "no options")
    end

    def local_plug(conn, [option]) do
      Conn.put_private(conn, :extra_local_plug_option, option)
    end
  end

  use ApicalTest.EndpointCase

  alias Plug.Conn

  def global(conn, _) do
    resp =
      conn.private
      |> Map.take([
        :extra_module_plug,
        :extra_module_plug_option,
        :extra_local_plug,
        :extra_local_plug_option
      ])
      |> Jason.encode!()

    conn
    |> Conn.put_resp_header("content-type", "application/json")
    |> Conn.resp(200, resp)
  end

  describe "routing" do
    test "adds extra plugs", %{conn: conn} do
      assert %{
               "extra_module_plug" => "no options",
               "extra_module_plug_option" => "module option",
               "extra_local_plug" => "no options",
               "extra_local_plug_option" => "local option"
             } ==
               conn
               |> get("/global")
               |> json_response(200)
    end
  end
end
