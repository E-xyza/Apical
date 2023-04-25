defmodule Apical.Parser.Query.Marshal do
  def array(array, %{elements: {prefix_type, tail_type}}) do
    array_marshal(array, prefix_type, tail_type, [])
  end

  def array(array, _), do: array

  # fastlane this
  defp array_marshal(array, [], [:string], []), do: array

  defp array_marshal([], _, _, so_far), do: Enum.reverse(so_far)

  defp array_marshal([first | rest], [], tail_type, so_far) do
    array_marshal(rest, [], tail_type, [as_type(first, tail_type) | so_far])
  end

  defp array_marshal([first | rest], [first_type | rest_type], tail_type, so_far) do
    array_marshal(rest, rest_type, tail_type, [as_type(first, first_type) | so_far])
  end

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
        types = Map.get(property_types, key) ->
          {key, as_type(value, types)}

        types = Enum.find_value(pattern_types, &(Regex.match?(elem(&1, 0), key) and elem(&1, 1))) ->
          {key, as_type(value, types)}

        true ->
          {key, as_type(value, additional_type)}
      end
    end)
  end

  def as_type("", [:null | _]), do: nil
  def as_type("null", [:null | rest]), do: nil
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
