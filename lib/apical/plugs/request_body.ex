defmodule Apical.Plugs.RequestBody do
  @behaviour Plug

  alias Apical.Exceptions.InvalidContentTypeError
  alias Apical.Exceptions.MissingContentTypeError
  alias Plug.Conn.Query
  alias Plug.Conn

  @impl Plug
  def init([module, version, operation_id, media_type_string, parameters, plug_opts]) do
    {parsed_media_type, adapter} =
      with {:ok, type, subtype, params} <- Conn.Utils.media_type(media_type_string),
           {:ok, adapter} <- get_adapter(type, subtype, params, parameters, plug_opts) do
        {{type, subtype, params}, adapter}
      else
        :error ->
          raise CompileError,
            description: "invalid media type in router definition: #{media_type_string}"

        {:error, description} ->
          raise CompileError, description: description
      end

    plug_opts
    |> Map.new()
    |> add_validation(
      module,
      version,
      operation_id,
      media_type_string,
      parsed_media_type,
      parameters
    )
    |> add_nesting(parsed_media_type, plug_opts)
    |> add_adapter(adapter)
  end

  @impl Plug
  def call(conn, operations) do
    content_type_string = get_content_type_string(conn)

    content_type =
      case Conn.Utils.content_type(content_type_string) do
        {:ok, type, subtype, params} -> {type, subtype, params}
        :error -> raise InvalidContentTypeError, invalid_string: content_type_string
      end

    # TODO: make this respect limits set in configuration
    with {:ok, body, conn} <- Conn.read_body(conn),
         {m, f, a} = operations.adapter,
         {:ok, body_params} <- apply(m, f, [body | a]) do
      conn
      |> validate!(body_params, content_type_string, content_type, operations)
      |> Map.replace!(:body_params, body_params)
      |> Map.update!(:params, &update_params(&1, body_params, operations))
    else
      {:error, _} -> raise "fatal error"
    end
  end

  @spec get_content_type_string(Conn.t()) :: String.t()
  defp get_content_type_string(conn) do
    if content_type_header = List.keyfind(conn.req_headers, "content-type", 0, nil) do
      elem(content_type_header, 1)
    else
      raise MissingContentTypeError
    end
  end

  defp update_params(params, body_params, %{nest: nest}) when is_map(body_params) do
    # objects can also be forced into "_json" by setting :nest_all_json
    #
    # see: https://hexdocs.pm/plug/Plug.Parsers.JSON.html#module-options
    Map.put(params, nest, body_params)
  end

  defp update_params(params, body_params, _) when is_map(body_params) do
    # we merge params into body_params so that malicious payloads can't overwrite the cleared
    # type checking performed by the params parsing.
    Map.merge(body_params, params)
  end

  defp update_params(params, body_params, _) do
    # non-object JSON content is put into a "_json" field, this matches the functionality found
    # in Plug.Parsers.JSON
    #
    # see: https://hexdocs.pm/plug/Plug.Parsers.JSON.html#module-options
    Map.put(params, "_json", body_params)
  end

  @urlencoded_types [["object"], "object"]

  defp get_adapter("application", "json", _, _, _) do
    {:ok, {Jason, :decode, []}}
  end

  defp get_adapter("application", "x-www-form-urlencoded", _, %{"schema" => %{"type" => type}}, _)
       when type not in @urlencoded_types do
    {:error, "content-type `x-www-form-urlencoded` must have schema type `object`"}
  end

  defp get_adapter("application", "x-www-form-urlencoded", _, _, _) do
    {:ok, {__MODULE__, :urlencoded_parser, []}}
  end

  def urlencoded_parser(string) do
    {:ok, Query.decode(string)}
  end

  defp add_validation(operations, module, version, operation_id, media_type_string, media_type, %{
         "schema" => _schema
       }) do
    fun = {module, validator_name(version, operation_id, media_type_string)}

    Map.update(operations, :validations, %{media_type => fun}, &Map.put(&1, media_type, fun))
  end

  defp add_validation(operations, _, _, _, _, _, _), do: operations

  defp add_nesting(operations, {"application", "json", _params}, plug_opts) do
    if plug_opts[:nest_all_json] do
      Map.put(operations, :nest, "_json")
    else
      operations
    end
  end

  defp add_nesting(operations, _, _), do: operations

  defp add_adapter(operations, adapter) do
    Map.put(operations, :adapter, adapter)
  end

  defp validate!(conn, body_params, content_type_string, content_type, %{validations: validations}) do
    {module, fun} = fetch_validation!(validations, content_type_string, content_type)

    case apply(module, fun, [body_params]) do
      :ok ->
        conn

      {:error, reasons} ->
        raise Apical.Exceptions.ParameterError,
              [operation_id: conn.private.operation_id, in: :body] ++ reasons
    end
  end

  defp validate!(conn, _, _, _, _), do: conn

  def validator_name(version, operation_id, mimetype) do
    :"#{version}-body-#{operation_id}-#{mimetype}"
  end

  defp fetch_validation!(
         validations,
         content_type_string,
         content_type = {_req_type, _req_subtype, _req_param}
       ) do
    if validation =
         Enum.find_value(validations, fn
           {^content_type, fun} -> fun
           _ -> nil
         end) do
      validation
    else
      raise Plug.Parsers.UnsupportedMediaTypeError, media_type: content_type_string
    end
  end
end
