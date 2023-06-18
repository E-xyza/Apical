defmodule Apical.Plugs.Query do
  @behaviour Plug
  @behaviour Apical.Plugs.Parameter

  alias Apical.Plugs.Common

  @impl Plug
  def init(opts) do
    Common.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations) do
    conn = Apical.Conn.fetch_query_params!(conn, operations.parser_context)

    conn
    |> Common.filter_required(conn.query_params, :query, operations)
    |> Common.warn_deprecated(conn.query_params, :query, operations)
    |> Common.validate(conn.query_params, :query, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :query

  @impl Apical.Plugs.Parameter
  def default_style, do: "form"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style in ~w(form spaceDelimited pipeDelimited deepObject)
end
