defmodule Apical.Parser.Query do
  require Pegasus
  import NimbleParsec

  alias Apical.Parser.Query.Marshal

  Pegasus.parser_from_string(
    """
    # guards
    empty           <- ""
    ARRAY_GUARD     <- empty
    COMMA_GUARD     <- empty
    SPACE_GUARD     <- empty
    PIPE_GUARD      <- empty
    OBJECT_GUARD    <- empty
    RESERVED_GUARD  <- empty

    # characters
    ALPHA         <- [A-Za-z]
    DIGIT         <- [0-9]
    HEXDIG        <- [0-9A-Fa-f]
    sub_delims    <- "!" / "$" / "'" / "(" / ")" / "*" / "+" / ";"
    equals        <- "="
    ampersand     <- "&"
    comma         <- ","
    space         <- "%20"
    pipe          <- "%7C" / "%7c"
    pct_encoded   <- "%" HEXDIG HEXDIG
    open_br       <- "["
    close_br      <- "]"

    # characters, from the spec
    reserved      <- "/" / "?" / "[" / "]" / "!" / "$" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="

    iunreserved   <- ALPHA / DIGIT / "-" / "." /  "_" / "~" / ucschar
    ipchar        <- iunreserved / pct_encoded / sub_delims / ":" /  "@"
    ipchar_ns     <- !"%20" ipchar
    ipchar_np     <- !("%7C" / "%7c") ipchar
    ipchar_rs     <- ipchar / reserved

    # specialized array parsing
    form_array    <- COMMA_GUARD value? (comma value)*
    space_array   <- SPACE_GUARD value_ns? (space value_ns)*
    pipe_array    <- PIPE_GUARD value_np? (pipe value_np)*
    array_value   <- ARRAY_GUARD (form_array / space_array / pipe_array)

    # specialized object parsing
    form_object   <- COMMA_GUARD (value comma value)? (comma value comma value)*
    space_object  <- SPACE_GUARD (value_ns space value_ns)? (comma value_ns space value_ns)*
    pipe_object   <- PIPE_GUARD (value_np pipe value_np)? (comma value_np pipe value_np)*
    object_value  <- OBJECT_GUARD (form_object / space_object / pipe_object)

    value         <- ipchar+
    value_ns      <- ipchar_ns+
    value_np      <- ipchar_np+
    value_rs      <- ipchar_rs+

    key_part      <- ipchar+
    key_deep      <- key_part open_br key_part close_br
    value_part    <- equals (object_value / array_value / value_rs_part / value / "")
    value_rs_part <- RESERVED_GUARD value_rs+

    basic_query   <- key_part !"[" value_part?
    deep_object   <- key_deep value_part

    query_part    <- basic_query / deep_object
    query         <- query_part? (ampersand query_part?)*
    """,
    # guards
    empty: [ignore: true],
    ARRAY_GUARD: [post_traverse: :array_guard],
    OBJECT_GUARD: [post_traverse: :object_guard],
    COMMA_GUARD: [post_traverse: {:style_guard, [:comma_delimited]}],
    SPACE_GUARD: [post_traverse: {:style_guard, [:space_delimited]}],
    PIPE_GUARD: [post_traverse: {:style_guard, [:pipe_delimited]}],
    RESERVED_GUARD: [post_traverse: :reserved_guard],
    # small characters
    equals: [ignore: true],
    ampersand: [ignore: true],
    comma: [ignore: true],
    space: [ignore: true],
    pipe: [ignore: true],
    open_br: [ignore: true],
    close_br: [ignore: true],
    pct_encoded: [post_traverse: :percent_decode],
    # array parsing
    form_array: [tag: :array, post_traverse: :finalize_array],
    space_array: [tag: :array, post_traverse: :finalize_array],
    pipe_array: [tag: :array, post_traverse: :finalize_array],
    # object parsing
    form_object: [tag: :object, post_traverse: :finalize_object],
    space_object: [tag: :object, post_traverse: :finalize_object],
    pipe_object: [tag: :object, post_traverse: :finalize_object],
    # general parsing stuff
    key_part: [collect: true, post_traverse: :store_key],
    value: [collect: true],
    value_ns: [collect: true],
    value_np: [collect: true],
    value_rs: [collect: true],
    # query collection
    basic_query: [post_traverse: :handle_query_part, tag: true],
    deep_object: [post_traverse: :handle_deep_object]
  )

  # fastlane combinators.   Note this supplants the bytewise combinator supplied in the RFC.
  defcombinatorp(:ucschar, utf8_char(not: 0..255))

  defparsecp(:parse_query, parsec(:query) |> eos)

  def parse(string, context \\ %{})

  def parse(string, context) do
    case parse_query(string, context: context) do
      {:ok, result, "", context, _, _} ->
        query_parameters =
          result
          |> Map.new()
          |> merge_deep_objects(context)
          |> merge_exploded_arrays(context)

        case context do
          %{warnings: warnings} ->
            {:ok, query_parameters, warnings}

          _ ->
            {:ok, query_parameters}
        end

      {:error, "expected end of string", char, _, _, _} ->
        {:error, char}
    end
  end

  defp merge_deep_objects(collected_parameters, context = %{deep_objects: objects}) do
    Enum.reduce(objects, collected_parameters, fn {key, value}, acc ->
      object = Marshal.object(value, Map.get(context, key))
      Map.put(acc, key, object)
    end)
  end

  defp merge_deep_objects(parameters, _), do: parameters

  defp merge_exploded_arrays(collected_parameters, context = %{exploded_arrays: arrays}) do
    Enum.reduce(arrays, collected_parameters, fn {key, value}, acc ->
      array =
        value
        |> Enum.reverse()
        |> Marshal.array(Map.get(context, key))

      Map.put(acc, key, array)
    end)
  end

  defp merge_exploded_arrays(parameters, _), do: parameters

  # UTILITY GUARDS

  defguardp context_key_type(context, key)
            when :erlang.map_get(:type, :erlang.map_get(key, context))

  defguardp context_key_style(context)
            when :erlang.map_get(:style, :erlang.map_get(:erlang.map_get(:key, context), context))

  defguardp is_context_value_reserved(context)
            when :erlang.map_get(
                   :allow_reserved,
                   :erlang.map_get(:erlang.map_get(:key, context), context)
                 ) === true

  defp handle_query_part(rest_str, [{:basic_query, [key]} | rest], context, _line, _offset)
       when is_map_key(context, key) do
    value =
      context
      |> Map.get(key)
      |> parse_key_only

    {rest_str, [{key, value} | rest], context}
  end

  defp handle_query_part(rest_str, [{:basic_query, [key, value]} | rest], context, _line, _offset)
       when is_map_key(context, key) do
    case context do
      %{exploded_array_keys: exploded} ->
        if key in exploded do
          new_list =
            context
            |> get_in([:exploded_arrays, key])
            |> List.wrap()
            |> List.insert_at(0, parse_kv(value, Map.get(context, key)))

          new_exploded_arrays =
            context
            |> Map.get(:exploded_arrays, %{})
            |> Map.put(key, new_list)

          {rest_str, rest, Map.put(context, :exploded_arrays, new_exploded_arrays)}
        else
          {rest_str, [{key, parse_kv(value, Map.get(context, key))} | rest], context}
        end

      _ ->
        {rest_str, [{key, parse_kv(value, Map.get(context, key))} | rest], context}
    end
  end

  defp handle_query_part(rest_str, [{:basic_query, [key | _]} | rest], context, _line, _offset) do
    # ignore it if it's not specified, but do post a warning.
    message = "299 - the key `#{key}` is not specified in the schema"
    {rest_str, rest, Map.update(context, :warnings, [message], &[message | &1])}
  end

  defp handle_deep_object(rest_str, [value, value_key, key | rest], context, _line, _offset) do
    if key in context.deep_object_keys do
      {rest_str, rest,
       Map.update(
         context,
         :deep_objects,
         %{key => %{value_key => value}},
         &put_in(&1, [key, value_key], value)
       )}
    else
      {:error, []}
    end
  end

  defp parse_key_only(kv_spec) do
    case kv_spec do
      %{type: [:null | _]} -> nil
      %{type: [:boolean | _]} -> true
      _ -> ""
    end
  end

  defp parse_kv(string, kv_spec) do
    case kv_spec do
      %{style: {module, fun}} ->
        apply(module, fun, [string])

      %{style: {module, fun, args}} ->
        apply(module, fun, [string | args])

      %{type: types} ->
        Marshal.as_type(string, types)

      _ ->
        string
    end
  end

  defp percent_decode(rest_str, [a, b, "%" | rest], context, _line, _offset) do
    {rest_str, [List.to_integer([b, a], 16) | rest], context}
  end

  defp store_key(rest_str, [key | rest], context, _line, _offset) do
    {rest_str, [key | rest], Map.put(context, :key, key)}
  end

  for type <- [:object, :array] do
    defp unquote(:"#{type}_guard")(rest_str, list, context = %{key: key}, _, _)
         when is_map_key(context, key) and
                context_key_type(context, key) in [[unquote(type)], [:null, unquote(type)]] do
      {rest_str, list, context}
    end

    defp unquote(:"#{type}_guard")(_, _, _, _, _) do
      {:error, []}
    end
  end

  defp style_guard(rest_str, list, context, _, _, style)
       when context_key_style(context) == style do
    {rest_str, list, context}
  end

  defp style_guard(_rest_str, _list, _context, _, _, _), do: {:error, []}

  defp reserved_guard(rest_str, list, context, _, _) when is_context_value_reserved(context) do
    {rest_str, list, context}
  end

  defp reserved_guard(_rest_str, _list, _context, _, _) do
    {:error, []}
  end

  defp finalize_array(rest_str, [{:array, list} | rest], context = %{key: key}, _, _) do
    {rest_str, [Marshal.array(list, Map.get(context, key)) | rest], Map.delete(context, :key)}
  end

  defp finalize_object(rest_str, [{:object, object_list} | rest], context = %{key: key}, _, _) do
    marshalled_object =
      object_list
      |> to_pairs
      |> Marshal.object(Map.fetch!(context, key))

    {rest_str, [marshalled_object | rest], Map.delete(context, :key)}
  end

  defp to_pairs(object_list, so_far \\ [])

  defp to_pairs([a, b | rest], so_far) do
    to_pairs(rest, [{a, b} | so_far])
  end

  defp to_pairs([], so_far), do: so_far
end
