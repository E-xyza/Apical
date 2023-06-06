defmodule Apical.Conn do
  # stuff to do with the Plug.Conn struct that is specialized for Apical.

  alias Apical.Parser.Marshal
  alias Apical.Parser.Query
  alias Apical.Parser.Style
  alias Plug.Conn

  def fetch_query_params(conn, settings) do
    case Query.parse(conn.query_string, settings) do
      {:ok, parse_result, warnings} ->
        new_conn =
          conn
          |> Map.put(:query_params, parse_result)
          |> Map.update!(:params, &Map.merge(&1, parse_result))

        Enum.reduce(warnings, new_conn, fn warning, so_far ->
          Conn.put_resp_header(so_far, "warning", warning)
        end)

      {:ok, parse_result} ->
        conn
        |> Map.put(:query_params, parse_result)
        |> Map.update!(:params, &Map.merge(&1, parse_result))

      {:error, char} ->
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: :query,
          misparsed: char
    end
  end

  def fetch_path_params(conn, settings) do
    Map.new(conn.path_params, &fetch_kv(&1, conn.private.operation_id, settings))
  end

  defp fetch_kv({key, value}, operation_id, settings) do
    key_settings = Map.fetch!(settings, key)

    with {:ok, parsed} <- Style.parse(value, key, key_settings),
         {:ok, marshalled} <- Marshal.marshal(parsed, key_settings) do
      {key, marshalled}
    else
      {:error, msg} ->
        raise Apical.Exceptions.ParameterError,
          operation_id: operation_id,
          in: :path,
          reason: msg
    end
  end
end
