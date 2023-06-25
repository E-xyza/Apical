defmodule Apical.Plugs.RequestBody do
  @moduledoc """
  `Plug` module for parsing request bodies and placing them into params.

  ### init options

  There are several forms that the RequestBody plug may take.  The following
  forms are recognized:

  - `[:match]`

    Prepare the `conn` object for parsing the RequestBody plugs by obtaining
    the `content-type` and `content-length` header and setting private
    `:content_type` and `:content_length` keys, respectively.

    Raises appropriate errors early in the case that these headers are missing.

  - `[:not_matched]`

    Rejects request bodies with a 415 error since the supplied content-type
    does not match any media-types declared in the OpenAPI schema.

  - `[router_module, operation_id, media_type_string, parameters, plug_opts]`

    The router module is passed itself, the operation_id (as an atom),
    the media-type string for which the module applies, the requestBody
    map from the OpenAPI schema, and the plug_opts keyword list as elucidated
    by the router compiler.

  ### conn output for media-type plugs

  If the `content-type` header doesn't match the media-type string declared in
  the OpenApi schema, it is untouched.  Note that if it fails to match it
  should be caught by a `:not_matched` variant of the plug downstream.

  Depending on the RequestBody source plugin supplied, the `conn` struct after
  calling this plug may have the request body placed into the `params` map.
  It may or may not also trigger reading the conn's request body.  Note that
  fetching the request body may happen only once in the `conn`'s lifecycle.

  By default, the plugins are assigned to the media types as follows:

  | `application/json`                  | `Apical.Plugs.RequestBody.Json`        |
  | `application/x-www-form-urlencoded` | `Apical.Plugs.RequestBody.FormEncoded` |
  | `*/*`                               | `Apical.Plugs.RequestBody.Default`     |

  See documentation for the respective source plugins for more information.
  """

  @behaviour Plug

  alias Plug.Conn

  alias Apical.Plugs.RequestBody.FormEncoded
  alias Apical.Plugs.RequestBody.Json
  alias Apical.Plugs.RequestBody.Default
  alias Apical.Validators

  @impl Plug
  def init(:match), do: :match
  def init(:not_matched), do: :not_matched

  def init([module, operation_id, media_type_string, parameters, plug_opts]) do
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

    version = Keyword.fetch!(plug_opts, :version)

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
    conn
    |> Conn.put_private(:content_type, fetch_content_type!(conn))
    |> Conn.put_private(:content_length, fetch_content_length!(conn))
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

  defp fetch_content_type!(conn) do
    content_type_string =
      case Conn.get_req_header(conn, "content-type") do
        [content_type] -> content_type
        [] -> raise Apical.Exceptions.MissingContentTypeError
        [_ | _] -> raise Apical.Exceptions.MultipleContentTypeError
      end

    case Conn.Utils.media_type(content_type_string) do
      {:ok, type, subtype, params} ->
        {type, subtype, params}

      :error ->
        raise Apical.Exceptions.InvalidContentTypeError, invalid_string: content_type_string
    end
  end

  defp fetch_content_length!(conn) do
    content_length_string =
      case Conn.get_req_header(conn, "content-length") do
        [content_length] -> content_length
        [] -> raise Apical.Exceptions.MissingContentLengthError
        [_ | _] -> raise Apical.Exceptions.MultipleContentLengthError
      end

    case Integer.parse(content_length_string) do
      {content_length, ""} ->
        content_length

      _ ->
        raise Apical.Exceptions.InvalidContentLengthError, invalid_string: content_length_string
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

  #############################################################################
  ## builds request body plugs.  To be called at compilation step.

  @no_request_bodies {[], []}

  @spec make(JsonPtr.t(), schema :: map(), operation_id :: String.t(), plug_opts :: keyword()) ::
          {plugs :: [Macro.t()], validations :: [Macro.t()]}
  def make(pointer, schema, operation_id, plug_opts) do
    request_body_pointer = JsonPtr.join(pointer, "requestBody")

    case JsonPtr.resolve_json(schema, request_body_pointer) do
      {:ok, subschema} ->
        {plugs, validators} =
          do_make(subschema, request_body_pointer, schema, operation_id, plug_opts)

        bookended_plugs =
          [
            quote do
              plug(Apical.Plugs.RequestBody, :match)
            end
          ] ++
            plugs ++
            [
              quote do
                plug(Apical.Plugs.RequestBody, :not_matched)
              end
            ]

        {bookended_plugs, List.flatten(validators)}

      _ ->
        @no_request_bodies
    end
  end

  defp do_make(%{"$ref" => ref}, _, schema, operation_id, plug_opts) do
    # for now, don't handle remote refs
    pointer = JsonPtr.from_uri(ref)

    schema
    |> JsonPtr.resolve_json!(pointer)
    |> do_make(pointer, schema, operation_id, plug_opts)
  end

  defp do_make(%{"content" => content}, pointer, _schema, operation_id, plug_opts) do
    # TODO: filter out content_sources. and pass that into the plug without sending it
    # to the plug

    version = Keyword.fetch!(plug_opts, :version)

    content
    |> Enum.sort_by(&Conn.Utils.media_type(elem(&1, 0)), Apical.Plugs.RequestBody)
    |> Enum.map(fn {media_type, content_schema} ->
      {
        quote do
          plug(
            Apical.Plugs.RequestBody,
            [__MODULE__] ++
              unquote([operation_id, media_type, Macro.escape(content_schema), plug_opts])
          )
        end,
        Validators.make_quoted(
          content_schema,
          JsonPtr.join(pointer, ["content", media_type]),
          validator_name(version, operation_id, media_type),
          plug_opts
        )
      }
    end)
    |> Enum.unzip()
  end
end
