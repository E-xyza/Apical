defmodule Apical.Plugs.Path do
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
    |> Parameter.warn_deprecated(params, :path, operations)
    |> Parameter.validate(params, :path, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :path

  @impl Apical.Plugs.Parameter
  def default_style, do: "simple"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style in ~w(matrix label simple)
end
