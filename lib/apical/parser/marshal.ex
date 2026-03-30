defmodule Apical.Parser.Marshal do
  @moduledoc false

  # this module contains functions for marshalling values based on settings
  # passed from `schema` fields of parameters that are textual.  The
  # marshalling functions will respect JsonSchema to the point where it can.
  # This supports peeking into textual content and attempting to marshal
  # numbers, integers, booleans, and nulls.  These actions will tunnel into
  # nested arrays and objects but not will not traverse JSON Schema's `oneOf`,
  # `anyOf`, `allOf`, `not` or conditional keywords.  You may use these
  # keywords if your contents are string contents at the top level.

  def marshal(value, settings, _type) when is_list(value) do
    {:ok, array(value, settings)}
  end

  def marshal(value, settings, _type) when is_map(value) do
    {:ok, object(value, settings)}
  end

  def marshal(value, _, type) do
    {:ok, as_type(value, type)}
  end

  def array([""], _), do: []

  def array(array, %{elements: {prefix_type, tail_type}}) do
    array_marshal(array, prefix_type, tail_type, [])
  end

  def array(array, _), do: array

  # fastlane this
  defp array_marshal(array, [], [:string], []), do: array

  defp array_marshal([], _, _, so_far), do: Enum.reverse(so_far)

  defp array_marshal([first | rest], [], tail_type, so_far) do
    array_marshal(rest, [], tail_type, [marshal_element(first, tail_type) | so_far])
  end

  defp array_marshal([first | rest], [first_type | rest_type], tail_type, so_far) do
    array_marshal(rest, rest_type, tail_type, [marshal_element(first, first_type) | so_far])
  end

  # Marshal an array element based on its type context
  defp marshal_element(value, context) when is_map(context) and is_map(value) do
    object(value, context)
  end

  defp marshal_element(value, context) when is_map(context) and is_list(value) do
    array(value, context)
  end

  defp marshal_element(value, context) when is_map(context) do
    as_type(value, context[:type] || [:string])
  end

  defp marshal_element(value, types) when is_list(types) do
    as_type(value, types)
  end

  defp marshal_element(value, _), do: value

  def object(object, %{properties: {property_types, pattern_types, additional_type}}) do
    object_marshal(object, {property_types, pattern_types, additional_type})
  end

  def object(object, _), do: Map.new(object)

  # fastlane these
  defp object_marshal(object, {empty, empty, [:string]}) when empty === %{}, do: Map.new(object)

  defp object_marshal(object, {empty, empty, types}) when empty === %{} do
    Map.new(object, fn {k, v} -> {k, as_type(v, types)} end)
  end

  defp object_marshal(object, {property_types, pattern_types, additional_type}) do
    Map.new(object, fn {key, value} ->
      cond do
        prop_context = Map.get(property_types, key) ->
          {key, marshal_property(value, prop_context)}

        types =
            Enum.find_value(pattern_types, fn {pattern, types} ->
              # Pattern is stored as string, compile at runtime
              regex = if is_binary(pattern), do: Regex.compile!(pattern), else: pattern
              Regex.match?(regex, key) and types
            end) ->
          {key, as_type(value, types)}

        true ->
          {key, as_type(value, additional_type)}
      end
    end)
  end

  # Marshal a property value based on its context
  # If the context is a map with :type, :properties, or :elements, it's a nested context
  # Otherwise, it's a simple type list
  defp marshal_property(value, context) when is_map(context) and is_map(value) do
    # Nested object - recursively marshal
    object(value, context)
  end

  defp marshal_property(value, context) when is_map(context) and is_list(value) do
    # Nested array - recursively marshal
    array(value, context)
  end

  defp marshal_property(value, context) when is_map(context) do
    # Primitive with nested context - use the type from context
    as_type(value, context[:type] || [:string])
  end

  defp marshal_property(value, types) when is_list(types) do
    # Simple type list
    as_type(value, types)
  end

  defp marshal_property(value, _), do: value

  def as_type("", [:null | _]), do: nil
  def as_type("null", [:null | _rest]), do: nil
  def as_type(string, [:null | rest]), do: as_type(string, rest)
  def as_type("true", [:boolean | _]), do: true
  def as_type("false", [:boolean | _]), do: false
  def as_type(string, [:boolean | rest]), do: as_type(string, rest)

  def as_type(string, [:integer, :number | rest]),
    do: as_type(string, [:number | rest])

  def as_type(string, [:integer | rest]) do
    case Integer.parse(string) do
      {value, ""} -> value
      _ -> as_type(string, rest)
    end
  end

  def as_type(string, [:number | rest]) do
    case Integer.parse(string) do
      {value, ""} ->
        value

      _ ->
        case Float.parse(string) do
          {value, ""} -> value
          _ -> as_type(string, rest)
        end
    end
  end

  def as_type(string, _), do: string
end
