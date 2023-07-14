defmodule Apical.Plugs.Cookie do
  @moduledoc """
  `Plug` module for parsing cookie parameters and placing them into params.

  ### init options

  the plug initialization options are as follows:

  `[router_module, operation_id, parameters, plug_opts]`

  The router module is passed itself, the operation_id (as an atom),
  a list of parameters maps from the OpenAPI schema, one for each cookie
  parameter, and the plug_opts keyword list as elucidated by the router
  compiler.  Initialization will compile an optimized `operations` object
  which is used to parse cookie parameters from the request.

  ### conn output

  The `conn` struct after calling this plug will have cookie parameters
  declared in the OpenAPI schema placed into the `params` map.  Cookie
  parameters not declared in the OpenAPI schema are allowed.
  """

  alias Apical.Parser.Query
  alias Apical.Plugs.Parameter
  alias Apical.Exceptions.ParameterError

  @behaviour Parameter
  @behaviour Plug

  @impl Plug
  def init(opts) do
    Parameter.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations = %{parser_context: parser_context}) do
    params =
      with {_, value} <- List.keyfind(conn.req_headers, "cookie", 0) do
        case Query.parse(value, parser_context) do
          {:ok, result} ->
            result

          {:ok, result, _} ->
            result

          {:error, :odd_object, key, value} ->
            raise ParameterError,
              operation_id: conn.private.operation_id,
              in: :cookie,
              reason:
                "form object parameter `#{value}` for parameter `#{key}` has an odd number of entries"

          {:error, :custom, key, payload} ->
            style_name =
              parser_context
              |> Map.fetch!(key)
              |> Map.fetch!(:style_name)

            raise ParameterError,
                  ParameterError.custom_fields_from(
                    conn.private.operation_id,
                    :cookie,
                    style_name,
                    key,
                    payload
                  )
        end
      else
        nil -> %{}
      end

    # TODO: make this recursive

    conn
    |> Parameter.check_required(params, :cookie, operations)
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Parameter.warn_deprecated(:cookie, operations)
    |> Parameter.custom_marshal(:cookie, operations)
    |> Parameter.validate(:cookie, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :cookie

  @impl Apical.Plugs.Parameter
  def default_style, do: "form"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style === "form"
end
