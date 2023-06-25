defmodule Apical.Conn do
  @moduledoc false

  # module that contains specialized function that act on the Plug.Conn struct
  # these operations are specialized for Apical.

  alias Apical.Exceptions.ParameterError
  alias Apical.Parser.Marshal
  alias Apical.Parser.Query
  alias Apical.Parser.Style
  alias Plug.Conn

  defp style_description(:form), do: "comma delimited"
  defp style_description(:space_delimited), do: "space delimited"
  defp style_description(:pipe_delimited), do: "pipe delimited"

  def fetch_query_params!(conn, settings) do
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

      {:error, :odd_object, key, value} ->
        style =
          settings
          |> Map.fetch!(key)
          |> Map.get(:style, :form)
          |> style_description

        raise ParameterError,
          operation_id: conn.private.operation_id,
          in: :query,
          reason:
            "#{style} object parameter `#{value}` for parameter `#{key}` has an odd number of entries"

      {:error, :custom, property, payload} ->
        style_name =
          settings
          |> Map.fetch!(property)
          |> Map.fetch!(:style_name)

        raise ParameterError,
              ParameterError.custom_fields_from(
                conn.private.operation_id,
                :query,
                style_name,
                property,
                payload
              )

      {:error, :misparse, misparse_location} ->
        raise ParameterError,
          operation_id: conn.private.operation_id,
          in: :query,
          misparsed: misparse_location
    end
  end

  def fetch_path_params!(conn, settings) do
    Map.new(conn.path_params, &fetch_kv(&1, conn.private.operation_id, :path, settings))
  end

  # TODO: make this recursive

  def fetch_header_params!(conn, settings) do
    conn.req_headers
    |> Enum.filter(&is_map_key(settings, elem(&1, 0)))
    |> Map.new(&fetch_kv(&1, conn.private.operation_id, :header, settings))
  end

  defp fetch_kv({key, value}, operation_id, where, settings) do
    key_settings = Map.fetch!(settings, key)

    style = Map.get(key_settings, :style, :simple)

    type =
      key_settings
      |> Map.get(:type)
      |> List.wrap()

    explode = Map.get(key_settings, :explode)

    with {:ok, parsed} <- Style.parse(value, key, style, type, explode),
         {:ok, marshalled} <- Marshal.marshal(parsed, key_settings, type) do
      {key, marshalled}
    else
      {:error, msg} ->
        raise ParameterError,
          operation_id: operation_id,
          in: where,
          reason: msg

      {:error, :custom, property, payload} ->
        style_name =
          settings
          |> Map.fetch!(key)
          |> Map.fetch!(:style_name)

        raise ParameterError,
              ParameterError.custom_fields_from(
                operation_id,
                where,
                style_name,
                property,
                payload
              )
    end
  end
end
