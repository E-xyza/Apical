defmodule Apical.Parser.Query.Marshal do
  def array(array, %{elements: {prefix_type, tail_type}}) do
    array_marshal(array, prefix_type, tail_type, [])
  end

  def array(array, _), do: array

  def array_marshal([], _, _, so_far), do: Enum.reverse(so_far)

  def array_marshal([first | rest], [], tail_type, so_far) do
    array_marshal(rest, [], tail_type, [as_type(first, tail_type) | so_far])
  end

  def array_marshal([first | rest], [first_type | rest_type], tail_type, so_far) do
    array_marshal(rest, rest_type, tail_type, [as_type(first, first_type) | so_far])
  end

  def as_type("", [:null | _]), do: nil
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
