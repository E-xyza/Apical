defmodule Apical.Parser.Style do
  @moduledoc false

  def parse(value, key, :simple, type, explode) do
    cond do
      :array in type ->
        case value do
          "" -> {:ok, []}
          _ -> {:ok, String.split(value, ",")}
        end

      :object in type ->
        case value do
          "" ->
            {:ok, %{}}

          _ ->
            value
            |> String.split(",")
            |> collect(explode)
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

      true ->
        {:ok, value}
    end
  end

  def parse("." <> value, key, :label, type, explode) do
    parsed =
      cond do
        :array in type ->
          {:ok, String.split(value, ".")}

        explode && :object in type ->
          value
          |> String.split(".")
          |> collect(explode)

        :object in type ->
          value
          |> String.split(".")
          |> into_map(%{})

        String.contains?(value, ".") ->
          {:error,
           "label object parameter `.#{value}` for parameter `#{key}` has multiple entries for a primitive type"}

        true ->
          {:ok, value}
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

  def parse(value, key, :label, _, _) do
    {:error,
     "label style `#{value}` for parameter `#{key}` is missing a leading dot, use format: `.value1.value2.value3...`"}
  end

  def parse(";" <> value, key, :matrix, type, explode) do
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
      :null in type and value === key ->
        {:ok, nil}

      :array in type ->
        if match?([{_, [""]}], split) do
          {:ok, []}
        else
          matrix_array_parse(split, key, explode)
        end

      :object in type ->
        if match?([{_, [""]}], split) do
          {:ok, %{}}
        else
          case matrix_object_parse(split, key, explode) do
            ok = {:ok, _} ->
              ok

            {:error, :odd} ->
              {:error,
               "matrix object parameter `;#{value}` for parameter `#{key}` has an odd number of entries"}

            error = {:error, _} ->
              error
          end
        end

      value === key ->
        {:ok, if(:boolean in type, do: "true", else: "")}

      String.contains?(value, ";") ->
        {:error,
         "matrix object parameter `.#{value}` for parameter `#{key}` has multiple entries for a primitive type"}

      String.starts_with?(value, "#{key}=") ->
        {:ok, String.replace_leading(value, "#{key}=", "")}

      true ->
        {:error,
         "matrix style `#{value}` for parameter `#{key}` is malformed, use format: `;#{key}=...`"}
    end
  end

  def parse(value, key, :matrix, _, _explode) do
    {:error,
     "matrix style `#{value}` for parameter `#{key}` is missing a leading semicolon, use format: `;#{key}=...`"}
  end

  def parse(value, _key, {m, f, a}, _, _explode) do
    result = apply(m, f, [value | a])

    case result do
      ok = {:ok, _} ->
        ok

      {:error, msg} ->
        {:error, :custom, value, msg}
    end
  end

  def parse(value, _, _, _, _?), do: {:ok, value}

  defp matrix_array_parse(split, key, explode) do
    if explode do
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

  defp matrix_object_parse(parsed, key, explode) do
    if explode do
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

  defp collect(parts, true) do
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

  defp collect(parts, _explode?), do: into_map(parts, %{})

  defp into_map([k, v | rest], so_far), do: into_map(rest, Map.put(so_far, k, v))
  defp into_map([], so_far), do: {:ok, so_far}
  defp into_map(_, _), do: {:error, :odd}
end
