defmodule Apical.Conn do
  # stuff to do with the Plug.Conn struct that is specialized for Apical.

  alias Apical.Parser.Query
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
    end
  end
end
