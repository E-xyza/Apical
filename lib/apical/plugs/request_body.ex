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
      parameters
    )
    |> add_source(source, plug_opts)
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

  def validator_name(version, operation_id, mimetype) do
    :"#{version}-body-#{operation_id}-#{mimetype}"
  end

  defp add_validation(operations, module, version, operation_id, media_type_string, %{
         "schema" => _schema
       }) do
    fun = {module, validator_name(version, operation_id, media_type_string)}
    Map.put(operations, :validator, fun)
  end

  defp add_validation(operations, _, _, _, _, _), do: operations

  @impl Plug

  # extraction phase.  This is pulled out as its own phase so that we don't
  # have to perform the req_header dance more than once.  It's included as
  # a part of this plug so that the code can be organized in the same place.
  def call(conn, :match) do
    with [content_type] <- Conn.get_req_header(conn, "content-type"),
         {{:ok, type, subtype, params}, _} <- {Conn.Utils.media_type(content_type), content_type} do
      Conn.put_private(conn, :content_type, {type, subtype, params})
    else
      {:error, _content_type} ->
        raise "do better"

      [] ->
        raise Apical.Exceptions.MissingContentTypeError

      [_ | _] ->
        raise "robot butt"
    end
  end

  # once matched, we skip all further steps.
  def call(conn = %{private: %{apical_content_type_matched: true}}, _), do: conn

  def call(conn, :not_matched) do
    [content_type] = Conn.get_req_header(conn, "content-type")
    raise Plug.Parsers.UnsupportedMediaTypeError, media_type: content_type
  end

  def call(conn, operations) do
    with true <- matches_req_header?(conn.private.content_type, operations.media_type),
         {source, opts} = operations.source,
         {:ok, conn} <- source.fetch(conn, Map.get(operations, :validator), opts) do
      Conn.put_private(conn, :apical_content_type_matched, true)
    else
      false ->
        conn

      {:error, keyword} ->
        params =
          if message = Keyword.get(keyword, :message) do
            {:reason, "error fetching request body#{message}"}
          end
          |> List.wrap()
          |> Keyword.merge(keyword)
          |> Keyword.merge(in: :body, operation_id: conn.private.operation_id)
          |> Keyword.drop([:message])

        raise Apical.Exceptions.ParameterError, params
    end
  end

  # same content-type
  defp matches_req_header?({type, subtype, req_params}, {type, subtype, tgt_params}) do
    params_subset?(req_params, tgt_params)
  end

  # generic media-subtype
  defp matches_req_header?({type, _subtype, req_params}, {type, "*", tgt_params}) do
    params_subset?(req_params, tgt_params)
  end

  # generic media-type
  defp matches_req_header?({_type, _subtype, req_params}, {"*", "*", tgt_params}) do
    params_subset?(req_params, tgt_params)
  end

  defp matches_req_header?(_, _), do: false

  # fastlane to avoid Enum.all, this is going to be extremely common.
  defp params_subset?(_, tgt_params) when tgt_params === %{}, do: true

  defp params_subset?(req_params, tgt_params) do
    Enum.all?(tgt_params, fn {key, value} -> Map.get(req_params, key) == value end)
  end

  defp add_source(operations, {mod, mod_opts}, plug_opts) do
    new_mod_opts =
      plug_opts
      |> Keyword.take([:nest_all_json])
      |> Keyword.merge(mod_opts)

    Map.put(operations, :source, {mod, new_mod_opts})
  end

  # sorting function sorts based on content-type string, with more generic
  # media-type strings coming after less generic media-type strings

  def compare(:error, _), do: raise("bad media type")
  def compare(_, :error), do: raise("bad media type")

  def compare(same, same), do: :eq

  def compare({:ok, type, subtype, map_a}, {:ok, type, subtype, map_b}) do
    case {map_size(map_a), map_size(map_b)} do
      {same, same} when map_a > map_b -> :gt
      {same, same} when map_a < map_b -> :lt
      {lhs, rhs} when lhs > rhs -> :lt
      {lhs, rhs} when lhs < rhs -> :gt
    end
  end

  def compare({:ok, type, "*", _}, {:ok, type, _, _}), do: :gt
  def compare({:ok, type, _, _}, {:ok, type, "*", _}), do: :lt

  def compare({:ok, type, subtype_a, _}, {:ok, type, subtype_b, _}) do
    cond do
      subtype_a > subtype_b -> :gt
      subtype_a < subtype_b -> :lt
    end
  end

  def compare({:ok, "*", _, _}, {:ok, _, _, _}), do: :gt
  def compare({:ok, _, _, _}, {:ok, "*", _, _}), do: :lt

  def compare({:ok, type_a, _, _}, {:ok, type_b, _, _}) do
    cond do
      type_a > type_b -> :gt
      type_a < type_b -> :lt
    end
  end
end
