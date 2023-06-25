defmodule Apical.Exceptions.MissingContentLengthError do
  @moduledoc """
  Error raised when the `content-length` header is missing from the request.

  This error should result in a http 411 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/411
  """

  defexception plug_status: 411

  def message(_), do: "missing content-length header"
end

defmodule Apical.Exceptions.MultipleContentLengthError do
  @moduledoc """
  Error raised multiple `content-length` headers are provided by the request.

  This error should result in a http 411 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/411
  """

  defexception plug_status: 411

  def message(_), do: "multiple content-length headers found"
end

defmodule Apical.Exceptions.InvalidContentLengthError do
  @moduledoc """
  Error raised when the `content-length` header does not parse to a valid
  integer.

  This error should result in a http 411 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/411
  """

  defexception [:invalid_string, plug_status: 411]

  def message(error), do: "invalid content-length header provided: #{error.invalid_string}"
end
