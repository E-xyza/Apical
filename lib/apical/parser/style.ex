defmodule Apical.Parser.Style do
  @moduledoc false

  # TODO: The API for this module needs to be revised once we know better what
  # is in common between path, cookie, and header parameters

  def parse(conn, key, value, settings = %{style: :comma_delimited, type: type}) do
    cond do
      :array in type ->
        {key, String.split(value, ",")}

      :object in type ->
        map =
          value
          |> String.split(",")
          |> comma_into_map(settings)

        {key, map}
    end
  catch
    :object_odd ->
      raise Apical.Exceptions.ParameterError,
        operation_id: conn.private.operation_id,
        in: :query,
        reason:
          "comma delimited object parameter `#{value}` for parameter `#{key}` has an odd number of entries"

    {:bad_form, str} ->
      raise Apical.Exceptions.ParameterError,
        operation_id: conn.private.operation_id,
        in: :query,
        reason:
          "comma delimited object parameter `#{value}` for parameter `#{key}` has a malformed entry: `#{str}`"
  end

  def parse(conn, key, "." <> value, settings = %{style: :label, type: type}) do
    cond do
      :array in type ->
        {key, String.split(value, ".")}

      Map.get(settings, :explode) && :object in type ->
        object =
          value
          |> String.split(".")
          |> comma_into_map(settings)

        {key, object}

      :object in type ->
        object =
          value
          |> String.split(".")
          |> into_map(%{})

        {key, object}
    end
  catch
    :object_odd ->
      raise Apical.Exceptions.ParameterError,
        operation_id: conn.private.operation_id,
        in: :query,
        reason:
          "label object parameter `#{value}` for parameter `#{key}` has an odd number of entries"

    {:bad_form, str} ->
      raise Apical.Exceptions.ParameterError,
        operation_id: conn.private.operation_id,
        in: :query,
        reason:
          "label object parameter `#{value}` for parameter `#{key}` has a malformed entry: `#{str}`"
  end

  def parse(conn, key, value, %{style: :label}) do
    raise Apical.Exceptions.ParameterError,
      operation_id: conn.private.operation_id,
      in: :path,
      reason:
        "label style `#{value}` for parameter `#{key}` is missing a leading dot, use format: `.value1.value2.value3...`"
  end

  def parse(conn, key, ";" <> value, settings = %{style: :matrix, type: type}) do
    parsed =
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
        {key, matrix_array_parse(conn, parsed, key, Map.get(settings, :explode))}

      :object in type ->
        {key, matrix_object_parse(conn, parsed, key, Map.get(settings, :explode))}
    end
  catch
    :object_odd ->
      raise Apical.Exceptions.ParameterError,
        operation_id: conn.private.operation_id,
        in: :query,
        reason:
          "comma delimited object parameter `#{value}` for parameter `#{key}` has an odd number of entries"
  end

  def parse(conn, key, value, %{style: :matrix}) do
    raise Apical.Exceptions.ParameterError,
      operation_id: conn.private.operation_id,
      in: :path,
      reason:
        "matrix style `#{value}` for parameter `#{key}` is missing a leading semicolon, use format: `;#{key}=...`"
  end

  def parse(_conn, key, value, %{}), do: {key, value}

  defp matrix_array_parse(conn, parsed, key, explode?) do
    if explode? do
      Enum.map(parsed, fn
        {^key, [v]} ->
          v

        {other, _} ->
          raise Apical.Exceptions.ParameterError,
            operation_id: conn.private.operation_id,
            in: :path,
            reason:
              "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...;#{key}=...`"
      end)
    else
      case parsed do
        [{^key, v}] ->
          v

        [{other, _}] ->
          raise Apical.Exceptions.ParameterError,
            operation_id: conn.private.operation_id,
            in: :path,
            reason:
              "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...`"
      end
    end
  end

  defp matrix_object_parse(conn, parsed, key, explode?) do
    if explode? do
      Map.new(parsed, fn {key, vals} -> {key, Enum.join(vals, ",")} end)
    else
      case parsed do
        [{^key, values}] ->
          into_map(values, %{})

        [{other, _}] ->
          raise Apical.Exceptions.ParameterError,
            operation_id: conn.private.operation_id,
            in: :path,
            reason:
              "matrix key `#{other}` provided for array named `#{key}`, use format: `;#{key}=...`"
      end
    end
  end

  defp comma_into_map(parts, %{explode: true}) do
    Map.new(parts, fn str ->
      case String.split(str, "=") do
        [key, val] -> {key, val}
        [key] -> {key, ""}
        _ -> throw({:bad_form, str})
      end
    end)
  end

  defp comma_into_map(parts, _), do: into_map(parts, %{})

  defp into_map([k, v | rest], so_far), do: into_map(rest, Map.put(so_far, k, v))
  defp into_map([], so_far), do: so_far
  defp into_map(_, _), do: throw(:object_odd)
end
