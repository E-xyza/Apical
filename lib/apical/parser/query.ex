defmodule Apical.Parser.Query do
  require Pegasus
  import NimbleParsec

  Pegasus.parser_from_string(
    """
    # guards
    empty        <- ""
    ARRAY_GUARD  <- empty
    FORM_GUARD   <- empty
    SPACE_GUARD  <- empty
    PIPE_GUARD   <- empty
    OBJECT_GUARD <- empty

    # characters
    ALPHA        <- [A-Za-z]
    DIGIT        <- [0-9]
    HEXDIG       <- [0-9A-Fa-f]
    sub_delims   <- "!" / "$" / "'" / "(" / ")" / "*" / "+" / ";"
    equals       <- "="
    ampersand    <- "&"
    comma        <- ","
    space        <- "%20"
    pipe         <- "%7C" / "%7c"
    pct_encoded  <- "%" HEXDIG HEXDIG
    open_br      <- "["
    close_br     <- "]"

    # characters, from the spec
    iunreserved  <- ALPHA / DIGIT / "-" / "." /  "_" / "~" / ucschar
    ipchar       <- iunreserved / pct_encoded / sub_delims / ":" /  "@"
    ipchar_ns    <- !"%20" ipchar
    ipchar_np    <- !("%7C" / "%7c") ipchar

    # specialized array parsing
    form_array   <- FORM_GUARD value? (comma value)*
    space_array  <- SPACE_GUARD value_ns? (space value_ns)*
    pipe_array   <- PIPE_GUARD value_np? (pipe value_np)*
    array_value  <- ARRAY_GUARD (form_array / space_array / pipe_array)

    # specialized object parsing
    form_object  <- FORM_GUARD (value comma value)? (comma value comma value)*
    space_object <- SPACE_GUARD (value_ns space value_ns)? (comma value_ns space value_ns)*
    pipe_object  <- PIPE_GUARD (value_np pipe value_np)? (comma value_np pipe value_np)*
    object_value <- OBJECT_GUARD (form_object / space_object / pipe_object)

    value        <- ipchar+
    value_ns     <- ipchar_ns+
    value_np     <- ipchar_np+

    key_part     <- ipchar+
    key_deep     <- key_part open_br key_part close_br
    value_part   <- equals (object_value / array_value / value / "")

    basic_query  <- key_part !"[" value_part?
    deep_object  <- key_deep value_part

    query_part   <- basic_query / deep_object
    query        <- query_part? (ampersand query_part?)*
    """,
    # guards
    empty: [ignore: true],
    ARRAY_GUARD: [post_traverse: :array_guard],
    OBJECT_GUARD: [post_traverse: :object_guard],
    FORM_GUARD: [post_traverse: {:style_guard, [:form]}],
    SPACE_GUARD: [post_traverse: {:style_guard, [:space_delimited]}],
    PIPE_GUARD: [post_traverse: {:style_guard, [:pipe_delimited]}],
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
    # query collection
    basic_query: [post_traverse: :handle_query_part, tag: true],
    deep_object: [post_traverse: :handle_deep_object]
  )

  # reserved         <- IRI_gen_delims / IRI_sub_delims
  # gen_delims       <- ":" / "/" / "?" / "#" / "[" / "]" / "@"

  defcombinatorp(:ucschar, utf8_char(not: 0..255))

  defp handle_query_part(rest_str, [{:basic_query, [key]} | rest], context, _line, _offset) do
    {rest_str, [{key, parse_empty_query(context, key)} | rest], context}
  end

  defp handle_query_part(rest_str, [{:basic_query, [key, value]} | rest], context, _line, _offset) do
    {rest_str, [{key, parse_query(value, context, key)} | rest], context}
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

  defp parse_empty_query(context, key) do
    if key_settings = Map.get(context, key) do
      case List.wrap(key_settings[:type]) do
        [:null | _] -> nil
        [:boolean | _] -> true
        _ -> ""
      end
    else
      ""
    end
  end

  defp parse_query(string, context, key) when is_map_key(context, key) do
    if types = get_in(context, [key, :type]) do
      parse_query_type(string, types)
    end
  end

  defp parse_query(string, _, _), do: string

  defp parse_query_type("", [:null | _]), do: nil
  defp parse_query_type(string, [:null | rest]), do: parse_query_type(string, rest)
  defp parse_query_type("true", [:boolean | _]), do: true
  defp parse_query_type("false", [:boolean | _]), do: false
  defp parse_query_type(string, [:boolean | rest]), do: parse_query_type(string, rest)

  defp parse_query_type(string, [:integer, :number | rest]),
    do: parse_query_type(string, [:number | rest])

  defp parse_query_type(string, [:integer | rest]) do
    case Integer.parse(string) do
      {value, ""} -> value
      _ -> parse_query_type(string, rest)
    end
  end

  defp parse_query_type(string, [:number | rest]) do
    case Integer.parse(string) do
      {value, ""} ->
        value

      _ ->
        case Float.parse(string) do
          {value, ""} -> value
          _ -> parse_query_type(string, rest)
        end
    end
  end

  defp parse_query_type(string, _), do: string

  defp percent_decode(rest_str, [a, b, "%" | rest], context, _line, _offset) do
    {rest_str, [List.to_integer([b, a], 16) | rest], context}
  end

  defp store_key(rest_str, [key | rest], context, _line, _offset) do
    {rest_str, [key | rest], Map.put(context, :key, key)}
  end

  defguardp context_key_type(context, key)
            when :erlang.map_get(:type, :erlang.map_get(key, context))

  defguardp context_key_style(context)
            when :erlang.map_get(:style, :erlang.map_get(:erlang.map_get(:key, context), context))

  for type <- [:object, :array] do
    defp unquote(:"#{type}_guard")(rest_str, list, context = %{key: key}, _, _)
         when is_map_key(context, key) and context_key_type(context, key) == [unquote(type)] do
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

  defp finalize_array(rest_str, [{:array, list} | rest], context, _, _) do
    {rest_str, [list | rest], Map.delete(context, :key)}
  end

  defp finalize_object(rest_str, [{:object, object} | rest], context, _, _) do
    {rest_str, [to_object(object) | rest], Map.delete(context, :key)}
  end

  defp to_object(list, result \\ %{})
  defp to_object([key, value | rest], result), do: to_object(rest, Map.put(result, key, value))
  defp to_object([], result), do: result

  defparsecp(:parse_query, parsec(:query) |> eos)

  def parse(string, context \\ [])

  def parse(string, context) when is_map_key(context, :deep_object_keys) do
    case parse_query(string, context: context) do
      {:ok, result, _, context, _, _} ->
        deep_params = Map.get(context, :deep_objects, %{})

        params =
          result
          |> Map.new()
          |> Map.merge(deep_params)

        {:ok, params}
    end
  end

  def parse(string, context) do
    case parse_query(string, context: context) do
      {:ok, result, _, _, _, _} ->
        {:ok, Map.new(result)}
    end
  end
end
