defmodule Apical.Exceptions.ParameterError do
  defexception [
    :operation_id,
    :in,
    :misparsed,
    :absolute_keyword_location,
    :instance_location,
    :errors,
    :error_value,
    :matches,
    :reason,
    :required,
    :ref_trace,
    plug_status: 400
  ]

  def message(exception = %{reason: reason}) when is_binary(reason) do
    "Parameter Error in operation #{exception.operation_id} (in #{exception.in}): #{reason}"
  end

  def message(exception = %{misparsed: nil}) do
    "Parameter Error in operation #{exception.operation_id} (in #{exception.in}): #{describe_exonerate(exception)}"
  end

  def message(exception) do
    "Parameter Error in operation #{exception.operation_id} (in #{exception.in}): invalid character #{exception.misparsed}"
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

    "value #{inspect(exception.error_value)} at `#{exception.instance_location}` fails schema criterion at `#{exception.absolute_keyword_location}`#{etc}"
  end
end
