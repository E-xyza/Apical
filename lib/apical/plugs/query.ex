defmodule Apical.Plugs.Query do
  alias Apical.Plugs.Parameter

  @behaviour Parameter
  @behaviour Plug

  @impl Plug
  def init(opts) do
    Parameter.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations) do
    conn = Apical.Conn.fetch_query_params!(conn, operations.parser_context)

    conn
    |> Parameter.filter_required(conn.query_params, :query, operations)
    |> Parameter.warn_deprecated(conn.query_params, :query, operations)
    |> Parameter.validate(conn.query_params, :query, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :query

  @impl Apical.Plugs.Parameter
  def default_style, do: "form"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style in ~w(form spaceDelimited pipeDelimited deepObject)
end
