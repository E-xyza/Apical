defmodule Apical.Plugs.Accept do
  @moduledoc """
  `Plug` module for validating Accept headers against response content types.

  This plug validates that the client's Accept header matches at least one of
  the content types defined in the OpenAPI schema's response section.

  ### init options

  - `[available_types, operation_id]`

    where `available_types` is a list of media type strings from the response
    content definition, and `operation_id` is the operation identifier.

  ### Behavior

  - If no Accept header is present, the request passes (RFC 7231: client accepts any)
  - If Accept header is `*/*`, the request passes
  - If any accepted type matches an available type (including wildcards), passes
  - If no match found, raises `Apical.Exceptions.NotAcceptableError` (406)

  ### Quality factors

  Accept headers with quality factors (q=X) are supported:
  - Types with q=0 are excluded from matching
  - Other quality values are used for preference ordering (but any match passes)
  """

  @behaviour Plug

  alias Plug.Conn
  alias Apical.Exceptions.NotAcceptableError

  @impl Plug
  def init([available_types, operation_id]) do
    # Pre-parse media types at compile time for efficiency
    parsed_types =
      Enum.map(available_types, fn type ->
        case Conn.Utils.media_type(type) do
          {:ok, main, sub, params} -> {main, sub, params}
          :error -> raise CompileError, description: "invalid media type: #{type}"
        end
      end)

    %{
      available_types: available_types,
      parsed_types: parsed_types,
      operation_id: operation_id
    }
  end

  @impl Plug
  def call(conn, operations) do
    case Conn.get_req_header(conn, "accept") do
      [] ->
        # No Accept header: client accepts any media type (RFC 7231)
        conn

      [accept_header] ->
        validate_accept(conn, accept_header, operations)

      [_ | _] ->
        # Multiple Accept headers - combine them (comma-separated)
        combined = conn |> Conn.get_req_header("accept") |> Enum.join(", ")
        validate_accept(conn, combined, operations)
    end
  end

  defp validate_accept(conn, accept_header, operations) do
    accepted_types = parse_accept_header(accept_header)

    if any_type_matches?(accepted_types, operations.parsed_types) do
      conn
    else
      raise NotAcceptableError,
        operation_id: operations.operation_id,
        accept: accept_header,
        available: operations.available_types
    end
  end

  @doc """
  Parses an Accept header into a list of {type, subtype, params, quality} tuples.

  Types with q=0 are filtered out as they explicitly reject that type.
  """
  def parse_accept_header(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_media_type_with_quality/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(fn {_, _, _, q} -> q == 0.0 end)
    |> Enum.sort_by(fn {_, _, _, q} -> -q end)
  end

  defp parse_media_type_with_quality(media_range) do
    # Split media type from parameters
    {media_type, params} = split_params(media_range)

    # Extract quality factor from params, default to 1.0
    {quality, other_params} = extract_quality(params)

    case Conn.Utils.media_type(media_type) do
      {:ok, type, subtype, _} ->
        {type, subtype, other_params, quality}

      :error ->
        nil
    end
  end

  defp split_params(media_range) do
    case String.split(media_range, ";", parts: 2) do
      [media_type] -> {String.trim(media_type), %{}}
      [media_type, params_str] -> {String.trim(media_type), parse_params(params_str)}
    end
  end

  defp parse_params(params_str) do
    params_str
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_param/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp parse_param(param) do
    case String.split(param, "=", parts: 2) do
      [key, value] -> {String.trim(key), String.trim(value)}
      _ -> nil
    end
  end

  defp extract_quality(params) do
    case Map.pop(params, "q") do
      {nil, params} -> {1.0, params}
      {q_str, params} -> {parse_quality(q_str), params}
    end
  end

  defp parse_quality(q_str) do
    case Float.parse(q_str) do
      {q, _} when q >= 0.0 and q <= 1.0 -> q
      _ -> 1.0
    end
  end

  @doc """
  Checks if any of the accepted types matches any of the available types.

  Handles wildcards:
  - `*/*` matches anything
  - `type/*` matches any subtype of that type
  """
  def any_type_matches?(accepted_types, available_types) do
    Enum.any?(accepted_types, fn accepted ->
      Enum.any?(available_types, fn available ->
        types_match?(accepted, available)
      end)
    end)
  end

  # Wildcard: */* matches anything
  defp types_match?({"*", "*", _, _}, _available), do: true

  # Type wildcard: type/* matches any subtype
  defp types_match?({type, "*", _, _}, {type, _, _}), do: true

  # Exact match (params not considered for accept matching)
  defp types_match?({type, subtype, _, _}, {type, subtype, _}), do: true

  # No match
  defp types_match?(_, _), do: false

  #############################################################################
  ## Build accept plug AST. To be called at compilation step.

  @spec make(JsonPtr.t(), schema :: map(), operation_id :: String.t(), plug_opts :: keyword()) ::
          Macro.t() | nil
  def make(pointer, schema, operation_id, plug_opts) do
    # Check if validate_accept is disabled
    if Keyword.get(plug_opts, :validate_accept, true) == false do
      nil
    else
      case extract_response_content_types(pointer, schema) do
        [] ->
          # No response content types defined, skip validation
          nil

        content_types ->
          quote do
            plug(Apical.Plugs.Accept, unquote([content_types, operation_id]))
          end
      end
    end
  end

  @doc """
  Extracts all content types from all responses of an operation.

  Looks at the responses object and collects content types from all response codes.
  """
  def extract_response_content_types(operation_pointer, schema) do
    responses_pointer = JsonPtr.join(operation_pointer, "responses")

    case JsonPtr.resolve_json(schema, responses_pointer) do
      {:ok, responses} when is_map(responses) ->
        responses
        |> Enum.flat_map(fn {_status_code, response} ->
          extract_content_types_from_response(response, schema)
        end)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  defp extract_content_types_from_response(%{"$ref" => ref}, schema) do
    pointer = JsonPtr.from_uri(ref)

    case JsonPtr.resolve_json(schema, pointer) do
      {:ok, resolved} -> extract_content_types_from_response(resolved, schema)
      _ -> []
    end
  end

  defp extract_content_types_from_response(%{"content" => content}, _schema)
       when is_map(content) do
    Map.keys(content)
  end

  defp extract_content_types_from_response(_, _), do: []
end
