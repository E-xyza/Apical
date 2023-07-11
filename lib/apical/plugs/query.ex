defmodule Apical.Plugs.Query do
  @moduledoc """
  `Plug` module for parsing query parameters and placing them into params.

  ### init options

  the plug initialization options are as follows:

  `[router_module, operation_id, parameters, plug_opts]`

  The router module is passed itself, the operation_id (as an atom),
  a list of parameters maps from the OpenAPI schema, one for each cookie
  parameter, and the plug_opts keyword list as elucidated by the router
  compiler.  Initialization will compile an optimized `operations` object
  which is used to parse query parameters from the request.

  ### conn output

  The `conn` struct after calling this plug will have query parameters
  declared in the OpenAPI schema placed into the `params` map.

  > ### Important {: .warning}
  >
  > If the client produces a query parameter that is not a part of the
  > OpenAPI schema, the request will fail with a 400 error.
  """

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
    |> Parameter.check_required(conn.query_params, :query, operations)
    |> Map.update!(:params, &Map.merge(&1, conn.query_params))
    |> Parameter.warn_deprecated(:query, operations)
    |> Parameter.validate(:query, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :query

  @impl Apical.Plugs.Parameter
  def default_style, do: "form"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style in ~w(form spaceDelimited pipeDelimited deepObject)
end
