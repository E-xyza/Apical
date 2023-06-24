defmodule Apical.Exceptions.MissingContentLengthError do
  defexception plug_status: 411

  def message(_), do: "missing content-length header"
end

defmodule Apical.Exceptions.MultipleContentLengthError do
  defexception plug_status: 411

  def message(_), do: "multiple content-length headers found"
end

defmodule Apical.Exceptions.InvalidContentLengthError do
  defexception [:invalid_string, plug_status: 411]

  def message(error), do: "invalid content-length header provided: #{error.invalid_string}"
end
