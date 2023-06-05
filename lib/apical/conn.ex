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

      {:error, char} ->
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: "query",
          misparsed: char
    end
  end

  def fetch_path_params(conn, settings) do
    Map.new(conn.path_params, fn
      {key, value} ->
        key_settings = Map.fetch!(settings, key)
        parse(conn, key, value, key_settings)
    end)
  end

  defp parse(_conn, key, value, %{style: :comma_delimited, type: type}) do
    if :array in type do
      {key, String.split(value, ",")}
    end
  end

  defp parse(_conn, key, "." <> value, %{style: :label, type: type}) do
    if :array in type do
      {key, String.split(value, ".")}
    end
  end

  defp parse(conn, key, ";" <> value, settings = %{style: :matrix, type: type}) do
    parsed =
      value
      |> String.split(";")
      |> Enum.map(fn
        part ->
          case String.split(part, "=") do
            [subkey] ->
              {subkey, []}

            [subkey, subvalue] ->
              {subkey, String.split(subvalue, ",")}
              # TODO: error when something strange happens
          end
      end)

    if :array in type do
      {key, matrix_array_parse(conn, parsed, key, Map.get(settings, :explode))}
    end
  end

  defp parse(_conn, key, value, %{}), do: {key, value}

  defp matrix_array_parse(conn, parsed, key, true) do
    Enum.map(parsed, fn
      {^key, [v]} -> v
      {other, _} ->
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: "path",
          reason:
            "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...,#{key}=...`"
    end)
  end

  defp matrix_array_parse(conn, parsed, key, _) do
    case parsed do
      [{^key, v}] ->
        v

      [{other, _}] ->
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: "path",
          reason:
            "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...`"
    end
  end
end
