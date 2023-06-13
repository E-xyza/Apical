defmodule Apical.Plugs.Cookie do
  @behaviour Plug
  @behaviour Apical.Plugs.Parameter

  alias Apical.Plugs.Common
  alias Plug.Conn

  @impl Plug
  def init(opts) do
    Common.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations) do
    conn = Conn.fetch_cookies(conn)

    cookies = conn.cookies

    # TODO: make this recursive
    operations
    |> Map.get(:required, [])
    |> Enum.each(fn
      required_cookie when is_map_key(cookies, required_cookie) ->
        :ok

      missing_cookie ->
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: :cookie,
          reason: "required cookie `#{missing_cookie}` not present"
    end)

    params = Apical.Conn.fetch_cookie_params(conn, operations.parser_context)

    conn
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Common.warn_deprecated(params, :cookie, operations)
    |> Common.validate(params, :cookie, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :cookie

  @impl Apical.Plugs.Parameter
  def default_style, do: "form"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style === "form"
end
