defmodule Apical.Plugs.Path do
  @behaviour Plug
  @behaviour Apical.Plugs.Parameter

  alias Apical.Tools
  alias Apical.Plugs.Common

  @impl Plug
  def init(opts = [_module, _version, operation_id, parameters, _plug_opts]) do
    Enum.each(parameters, fn parameter = %{"name" => name} ->
      Tools.assert(
        parameter["required"],
        "for parameter #{name} in operationId #{operation_id}: path parameters must be `required: true`"
      )
    end)

    Common.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations) do
    params = Apical.Conn.fetch_path_params(conn, operations.parser_context)

    conn
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Common.warn_deprecated(params, :path, operations)
    |> Common.validate(params, :path, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :path

  @impl Apical.Plugs.Parameter
  def default_style, do: "simple"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style in ~w(matrix label simple)
end
