defmodule Apical.Plugs.Cookie do
  @behaviour Plug
  @behaviour Apical.Plugs.Parameter

  alias Apical.Parser.Query
  alias Apical.Plugs.Common

  @impl Plug
  def init(opts) do
    Common.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations = %{parser_context: parser_context}) do
    cookie_params =
      with {_, value} <- List.keyfind(conn.req_headers, "cookie", 0) do
        case Query.parse(value, parser_context) do
          {:ok, result} ->
            result

          {:ok, result, _} ->
            result

          {:error, :odd_object, key, value} ->
            raise Apical.Exceptions.ParameterError,
              operation_id: conn.private.operation_id,
              in: :cookie,
              reason:
                "form object parameter `#{value}` for parameter `#{key}` has an odd number of entries"
        end
      else
        nil -> %{}
      end

    # TODO: make this recursive
    operations
    |> Map.get(:required, [])
    |> Enum.each(fn
      required_cookie when is_map_key(cookie_params, required_cookie) ->
        :ok

      missing_cookie ->
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: :cookie,
          reason: "required cookie `#{missing_cookie}` not present"
    end)

    conn
    |> Map.update!(:params, &Map.merge(&1, cookie_params))
    |> Common.warn_deprecated(cookie_params, :cookie, operations)
    |> Common.validate(cookie_params, :cookie, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :cookie

  @impl Apical.Plugs.Parameter
  def default_style, do: "form"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style === "form"
end
