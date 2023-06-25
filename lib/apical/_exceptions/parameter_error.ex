defmodule Apical.Exceptions.ParameterError do
  @moduledoc """
  Error raised when parameters are invalid.  Note that many of the fields
  correspond to error parameters returned by `Exonerate` validators.

  This error should result in a http 400 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400
  """

  @optional_keys ~w(operation_id
  in
  misparsed
  absolute_keyword_location
  instance_location
  errors
  error_value
  matches
  reason
  required
  ref_trace)a

  defexception @optional_keys ++ [plug_status: 400]

  @struct_keys @optional_keys ++ [:plug_status]

  def message(exception = %{reason: reason}) when is_binary(reason) do
    "Parameter Error in operation #{exception.operation_id} (in #{exception.in}): #{reason}"
  end

  def message(exception = %{misparsed: nil}) do
    "Parameter Error in operation #{exception.operation_id} (in #{exception.in}): #{describe_exonerate(exception)}"
  end

  def message(exception) do
    "Parameter Error in operation #{exception.operation_id} (in #{exception.in}): invalid character #{exception.misparsed}"
  end

  def custom_fields_from(operation_id, where, style_name, property, message)
      when is_binary(message) do
    custom_fields_from(operation_id, where, style_name, property, message: message)
  end

  def custom_fields_from(operation_id, where, style_name, property, contents)
      when is_list(contents) do
    tail =
      if message = Keyword.get(contents, :message) do
        ": #{message}"
      else
        ""
      end

    contents
    |> Keyword.take(@struct_keys)
    |> Keyword.merge(operation_id: operation_id, in: where)
    |> Keyword.put_new(
      :reason,
      "custom parser for style `#{style_name}` in property `#{property}` failed#{tail}"
    )
  end

  # TODO: improve this error by turning
  def describe_exonerate(exception) do
    etc =
      exception
      |> Map.take([:errors, :matches, :reason, :required, :ref_trace])
      |> Enum.flat_map(fn {key, value} ->
        List.wrap(if value, do: "#{key}: #{inspect(value)}")
      end)
      |> Enum.join(";\n")
      |> case do
        "" -> ""
        string -> ".\n#{string}"
      end

    json_value = Jason.encode!(exception.error_value)

    "value `#{json_value}` at `#{exception.instance_location}` fails schema criterion at `#{exception.absolute_keyword_location}`#{etc}"
  end
end
