defmodule Apical.Parser.Style do
  @moduledoc false

  # TODO: The API for this module needs to be revised once we know better what
  # is in common between path, cookie, and header parameters

  def parse(value, key, settings = %{style: :comma_delimited, type: type}) do
    cond do
      :array in type ->
        {:ok, String.split(value, ",")}

      :object in type ->
        value
        |> String.split(",")
        |> collect(settings)
        |> case do
          ok = {:ok, _} ->
            ok

          {:error, :odd} ->
            {:error,
             "comma delimited object parameter `#{value}` for parameter `#{key}` has an odd number of entries"}

          {:error, item} when is_binary(item) ->
            {:error,
             "comma delimited object parameter `#{value}` for parameter `#{key}` has a malformed entry: `#{item}`"}
        end
    end
  end

  def parse("." <> value, key, settings = %{style: :label, type: type}) do
    parsed =
      cond do
        :array in type ->
          {:ok, String.split(value, ".")}

        Map.get(settings, :explode) && :object in type ->
          value
          |> String.split(".")
          |> collect(settings)

        :object in type ->
          value
          |> String.split(".")
          |> into_map(%{})
      end

    case parsed do
      ok = {:ok, _} ->
        ok

      {:error, :odd} ->
        {:error,
         "label object parameter `.#{value}` for parameter `#{key}` has an odd number of entries"}

      {:error, item} when is_binary(item) ->
        {:error,
         "label object parameter `.#{value}` for parameter `#{key}` has a malformed entry: `#{item}`"}
    end
  end

  def parse(value, key, %{style: :label}) do
    {:error,
     "label style `#{value}` for parameter `#{key}` is missing a leading dot, use format: `.value1.value2.value3...`"}
  end

  def parse(";" <> value, key, settings = %{style: :matrix, type: type}) do
    split =
      value
      |> String.split(";")
      |> Enum.map(fn
        part ->
          case String.split(part, "=") do
            [subkey] ->
              {subkey, []}

            [subkey, subvalue] ->
              {subkey, String.split(subvalue, ",")}
              # TODO: error when something strange happens
          end
      end)

    cond do
      :array in type ->
        matrix_array_parse(split, key, Map.get(settings, :explode))

      :object in type ->
        case matrix_object_parse(split, key, Map.get(settings, :explode)) do
          ok = {:ok, _} -> ok
          {:error, :odd} ->
            {:error,
             "matrix object parameter `;#{value}` for parameter `#{key}` has an odd number of entries"}
          error = {:error, _} -> error
        end
    end
  end

  def parse(value, key, %{style: :matrix}) do
    {:error,
     "matrix style `#{value}` for parameter `#{key}` is missing a leading semicolon, use format: `;#{key}=...`"}
  end

  def parse(value, _key, %{}), do: {:ok, value}

  defp matrix_array_parse(split, key, explode?) do
    if explode? do
      split
      |> Enum.reduce_while({:ok, []}, fn
        {^key, [v]}, {:ok, acc} ->
          {:cont, {:ok, [v | acc]}}

        {other, _}, _ ->
          {:halt,
           {:error,
            "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...;#{key}=...`"}}
      end)
      |> case do
        {:ok, arr} -> {:ok, Enum.reverse(arr)}
        error -> error
      end
    else
      case split do
        [{^key, v}] ->
          {:ok, v}

        [{other, _}] ->
          {:error,
           "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...`"}
      end
    end
  end

  defp matrix_object_parse(parsed, key, explode?) do
    if explode? do
      {:ok, Map.new(parsed, fn {key, vals} -> {key, Enum.join(vals, ",")} end)}
    else
      case parsed do
        [{^key, values}] ->
          into_map(values, %{})

        [{other, _}] ->
          {:error,
           "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...`"}
      end
    end
  end

  defp collect(parts, %{explode: true}) do
    Enum.reduce_while(parts, {:ok, %{}}, fn
      part, {:ok, so_far} ->
        case String.split(part, "=") do
          [key, val] ->
            {:cont, {:ok, Map.put(so_far, key, val)}}

          [key] ->
            {:cont, {:ok, Map.put(so_far, key, "")}}

          _ ->
            {:halt, {:error, part}}
        end
    end)
  end

  defp collect(parts, _), do: into_map(parts, %{})

  defp into_map([k, v | rest], so_far), do: into_map(rest, Map.put(so_far, k, v))
  defp into_map([], so_far), do: {:ok, so_far}
  defp into_map(_, _), do: {:error, :odd}
end
