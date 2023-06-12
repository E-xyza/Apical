defmodule Apical.Exceptions.MissingContentTypeError do
  defexception plug_status: 400

  def message(_), do: "missing content-type header"
end

defmodule Apical.Exceptions.InvalidContentTypeError do
  defexception [:invalid_string, plug_status: 400]

  def message(error), do: "invalid content-type header provided: #{error.invalid_string}"
end
