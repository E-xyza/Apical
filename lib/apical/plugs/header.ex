defmodule Apical.Plugs.Header do
  @moduledoc """
  `Plug` module for parsing header parameters and placing them into params.

  ### init options

  the plug initialization options are as follows:

  `[router_module, operation_id, parameters, plug_opts]`

  The router module is passed itself, the operation_id (as an atom),
  a list of parameters maps from the OpenAPI schema, one for each cookie
  parameter, and the plug_opts keyword list as elucidated by the router
  compiler.  Initialization will compile an optimized `operations` object
  which is used to parse header parameters from the request.

  ### conn output

  The `conn` struct after calling this plug will have header parameters
  declared in the OpenAPI schema placed into the `params` map.  Header
  parameters not declared in the OpenAPI schema are allowed.
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
    params = Apical.Conn.fetch_header_params!(conn, operations.parser_context)

    conn
    |> Parameter.check_required(params, :header, operations)
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Parameter.warn_deprecated(:header, operations)
    |> Parameter.custom_marshal(:header, operations)
    |> Parameter.validate(:header, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :header

  @impl Apical.Plugs.Parameter
  def default_style, do: "simple"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style === "simple"
end
