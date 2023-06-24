defmodule Apical.Plugs.Header do
  alias Apical.Plugs.Parameter

  @behaviour Parameter
  @behaviour Plug

  @impl Plug
  def init(opts) do
    Parameter.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations) do
    params = Apical.Conn.fetch_header_params!(conn, operations.parser_context)

    conn
    |> Parameter.check_required(params, :header, operations)
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Parameter.warn_deprecated(params, :header, operations)
    |> Parameter.validate(params, :header, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :header

  @impl Apical.Plugs.Parameter
  def default_style, do: "simple"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style === "simple"
end
