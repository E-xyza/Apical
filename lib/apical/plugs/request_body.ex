defmodule Apical.Plugs.RequestBody do
  @moduledoc """
  performs matching, marshalling of request bodies, and fallthrough error
  for when no matching media type is found.
  """

  @behaviour Plug

  alias Plug.Conn

  alias Apical.Plugs.RequestBody.FormEncoded
  alias Apical.Plugs.RequestBody.Json
  alias Apical.Plugs.RequestBody.Default

  @impl Plug
  def init(:match), do: :match
  def init(:not_matched), do: :not_matched

  def init([module, version, operation_id, media_type_string, parameters, plug_opts]) do
    {parsed_media_type, source} =
      with {:ok, type, subtype, params} <- Conn.Utils.media_type(media_type_string) do
        parsed_media_type = {type, subtype, params}
        source = {source_module, _} = get_source(media_type_string, parsed_media_type, plug_opts)
        source_module.validate!(parameters, operation_id)
        {parsed_media_type, source}
      else
        :error ->
          raise CompileError,
            description: "invalid media type in router definition: #{media_type_string}"

        {:error, description} ->
          raise CompileError, description: description
      end

    plug_opts
    |> Map.new()
    |> Map.take(~w(source path)a)
    |> add_content_type(parsed_media_type)
    |> add_validation(
      module,
      version,
      operation_id,
      media_type_string,
      parsed_media_type,
      parameters
    )
    |> add_source(source)
  end

  defp get_source(media_type_string, parsed_media_type, plug_opts) do
    plug_opts
    |> Keyword.get(:content_sources, [])
    |> List.keyfind(media_type_string, 0)
    |> resolve_source(parsed_media_type)
  end

  defp resolve_source({_, source = {module, args}}, _) when is_atom(module) and is_list(args) do
    source
  end

  defp resolve_source({_, source}, _) when is_atom(source), do: {source, []}

  defp resolve_source(_, {"application", "x-www-form-urlencoded", _}), do: {FormEncoded, []}

  defp resolve_source(_, {"application", "json", _}), do: {Json, []}

  defp resolve_source(_, _), do: {Default, []}

  defp add_content_type(operations, parsed_media_type),
    do: Map.put(operations, :media_type, parsed_media_type)

  defp add_validation(operations, module, version, operation_id, media_type_string, media_type, %{
         "schema" => _schema
       }) do
    fun = {module, validator_name(version, operation_id, media_type_string)}

    Map.update(operations, :validations, %{media_type => fun}, &Map.put(&1, media_type, fun))
  end

  defp add_validation(operations, _, _, _, _, _, _), do: operations

  @impl Plug

  # extraction phase.  This is pulled out as its own phase so that we don't
  # have to perform the req_header dance more than once.  It's included as
  # a part of this plug so that the code can be organized in the same place.
  def call(conn, :match) do
    with [content_type] <- Conn.get_req_header(conn, "content-type"),
         {:ok, type, subtype, params} <- Conn.Utils.media_type(content_type) do
      Conn.put_private(conn, :content_type, {type, subtype, params})
    else
      [] ->
        raise Apical.Exceptions.MissingContentTypeError

      :error ->
        # TODO: fix this.
        raise "bad content-type string"
    end
  end

  # match checking phase.  This is pulled out as its own phase so that we can
  # pull apart each individual media type as its own plug in the pipeline.
  def call(conn = %{private: %{apical_content_type_matched: true}}, :not_matched), do: conn

  def call(_, :not_matched) do
    # TODO: fix this.
    raise "do better here"
  end

  def call(conn, operations) do
    with true <- match_req_header?(conn.private.content_type, operations.media_type),
         {source, opts} = operations.source,
         {:ok, conn} <- source.fetch(conn, opts) do
      Conn.put_private(conn, :apical_content_type_matched, true)
    else
      false ->
        conn

      {:error, keyword} ->
        message =
          case Keyword.fetch(keyword, :message) do
            {:ok, message} -> ": #{message}"
            :error -> ""
          end

        params =
          [reason: "error fetching request body#{message}"]
          |> Keyword.merge(keyword)
          |> Keyword.merge(in: :body)
          |> Keyword.drop([:message])

        raise Apical.Exceptions.ParameterError, params
    end
  end

  # same content-type
  defp match_req_header?({type, subtype, req_params}, {type, subtype, tgt_params}) do
    params_subset?(req_params, tgt_params)
  end
  # generic media-subtype
  defp match_req_header?({type, _subtype, req_params}, {type, "*", tgt_params}) do
    params_subset?(req_params, tgt_params)
  end
  # generic media-type
  defp match_req_header?({_type, _subtype, req_params}, {"*", "*", tgt_params}) do
    params_subset?(req_params, tgt_params)
  end

  defp match_req_header?(_, _), do: false

  defp params_subset?(req_params, tgt_params) do
    Enum.all?(tgt_params, fn {key, value} -> Map.get(req_params, key) == value end)
  end

  defp add_source(operations, source) do
    Map.put(operations, :source, source)
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
