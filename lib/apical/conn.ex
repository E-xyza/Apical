defmodule Apical.Conn do
  # stuff to do with the Plug.Conn struct that is specialized for Apical.

  alias Apical.Parser.Marshal
  alias Apical.Parser.Query
  alias Apical.Parser.Style
  alias Plug.Conn

  require Apical.Exceptions.ParameterError
  @error_keys Map.keys(Apical.Exceptions.ParameterError.__struct__())

  # TODO: rename these to not be "fetch"

  defp style_description(:form), do: "comma delimited"
  defp style_description(:space_delimited), do: "space delimited"
  defp style_description(:pipe_delimited), do: "pipe delimited"

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

      {:error, :odd_object, key, value} ->
        style =
          settings
          |> Map.fetch!(key)
          |> Map.get(:style, :form)
          |> style_description

        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: :query,
          reason:
            "#{style} object parameter `#{value}` for parameter `#{key}` has an odd number of entries"

      {:error, :custom, property, message} when is_binary(message) ->
        style_name = settings
        |> Map.fetch!(property)
        |> Map.fetch!(:style_name)

        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: :query,
          reason: "custom parser for style `#{style_name}` in property `#{property}` failed: #{message}"

      {:error, :custom, property, contents} when is_list(contents) ->
        tail = if message = Keyword.get(contents, :message) do
          ": #{message}"
        else
          ""
        end

        style_name = settings
        |> Map.fetch!(property)
        |> Map.fetch!(:style_name)

        fields =
          contents
          |> Keyword.take(@error_keys)
          |> Keyword.merge(operation_id: conn.private.operation_id, in: :query)
          |> Keyword.put_new(:reason, "custom parser for style `#{style_name}` in property `#{property}` failed#{tail}")

        raise Apical.Exceptions.ParameterError, fields

      {:error, :misparse, misparse_location} ->
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: :query,
          misparsed: misparse_location
    end
  end

  def fetch_path_params(conn, settings) do
    Map.new(conn.path_params, &fetch_kv(&1, conn.private.operation_id, :simple, settings))
  end

  # TODO: make this recursive

  def fetch_header_params(conn, settings) do
    conn.req_headers
    |> Enum.filter(&is_map_key(settings, elem(&1, 0)))
    |> Map.new(&fetch_kv(&1, conn.private.operation_id, :simple, settings))
  end

  defp fetch_kv({key, value}, operation_id, default_style, settings) do
    key_settings = Map.fetch!(settings, key)

    style = Map.get(key_settings, :style, default_style)

    type =
      key_settings
      |> Map.get(:type)
      |> List.wrap()

    explode? = Map.get(key_settings, :explode, false)

    with {:ok, parsed} <- Style.parse(value, key, style, type, explode?),
         {:ok, marshalled} <- Marshal.marshal(parsed, key_settings, type) do
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
