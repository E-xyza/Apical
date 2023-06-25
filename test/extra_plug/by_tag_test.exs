defmodule ApicalTest.ExtraPlug.ByTagTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    alias Plug.Conn

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: ByTagTest
        version: 1.0.0
      paths:
        "/global":
          get:
            operationId: global
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
      """,
      root: "/",
      controller: ApicalTest.ExtraPlug.ByTagTest,
      tags: [
        tag: [
          extra_plugs: [
            {:local_plug, ["local override"]},
            {ApicalTest.ExtraPlug, ["module override"]},
            :tag_only_plug
          ]
        ]
      ],
      extra_plugs: [
        :local_plug,
        {:local_plug, ["local option"]},
        ApicalTest.ExtraPlug,
        {ApicalTest.ExtraPlug, ["module option"]}
      ],
      encoding: "application/yaml"
    )

    def local_plug(conn, []) do
      Conn.put_private(conn, :extra_local_plug, "no options")
    end

    def local_plug(conn, [option]) do
      Conn.put_private(conn, :extra_local_plug_option, option)
    end

    def tag_only_plug(conn, []) do
      Conn.put_private(conn, :extra_tag_only_plug, "no options")
    end
  end

  use ApicalTest.EndpointCase

  alias Plug.Conn

  for operation <- ~w(global tagged)a do
    def unquote(operation)(conn, _) do
      resp =
        conn.private
        |> Map.take([
          :extra_module_plug,
          :extra_module_plug_option,
          :extra_local_plug,
          :extra_local_plug_option,
          :extra_tag_only_plug
        ])
        |> Jason.encode!()

      conn
      |> Conn.put_resp_header("content-type", "application/json")
      |> Conn.resp(200, resp)
    end
  end

  describe "routing" do
    test "globally adds extra plugs", %{conn: conn} do
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

    test "scoped to tag overrides extra plugs", %{conn: conn} do
      assert %{
               "extra_tag_only_plug" => "no options",
               "extra_module_plug_option" => "module override",
               "extra_local_plug_option" => "local override"
             } ==
               conn
               |> get("/tagged")
               |> json_response(200)
    end
  end
end
