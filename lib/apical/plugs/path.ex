defmodule Apical.Plugs.Path do
  @moduledoc """
  `Plug` module for parsing path parameters and placing them into params.

  ### init options

  the plug initialization options are as follows:

  `[router_module, operation_id, parameters, plug_opts]`

  The router module is passed itself, the operation_id (as an atom),
  a list of parameters maps from the OpenAPI schema, one for each cookie
  parameter, and the plug_opts keyword list as elucidated by the router
  compiler.  Initialization will compile an optimized `operations` object
  which is used to parse path parameters from the request.

  ### conn output

  The `conn` struct after calling this plug will have path parameters
  declared in the OpenAPI schema placed into the `params` map.

  > ### Important {: .warning}
  >
  > As part of the OpenAPI spec, path parameters must be declared in the
  > path key under the `paths` field of the schema.
  """

  alias Apical.Tools
  alias Apical.Plugs.Parameter

  @behaviour Plug
  @behaviour Parameter

  @impl Plug
  def init(opts = [_module, operation_id, parameters, plug_opts]) do
    Enum.each(parameters, fn parameter = %{"name" => name} ->
      Tools.assert(
        parameter["required"],
        "for parameter `#{name}` in operation `#{operation_id}`: path parameters must be `required: true`"
      )

      path_parameters = Keyword.get(plug_opts, :path_parameters, [])
      path = Keyword.fetch!(plug_opts, :path)

      Tools.assert(
        name in path_parameters,
        "that the parameter `#{name}` in operation `#{operation_id}` exists as a match in its path definition: (got: `#{path}`)"
      )
    end)

    Parameter.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations) do
    params = Apical.Conn.fetch_path_params!(conn, operations.parser_context)

    conn
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Parameter.warn_deprecated(:path, operations)
    |> Parameter.custom_marshal(:path, operations)
    |> Parameter.validate(:path, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :path

  @impl Apical.Plugs.Parameter
  def default_style, do: "simple"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style in ~w(matrix label simple)
end
