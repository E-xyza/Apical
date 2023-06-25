defmodule Apical.Exceptions.MissingContentTypeError do
  @moduledoc """
  Error raised when the `content-type` header is missing from the request.

  This error should result in a http 400 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400
  """

  defexception plug_status: 400

  def message(_), do: "missing content-type header"
end

defmodule Apical.Exceptions.MultipleContentTypeError do
  @moduledoc """
  Error raised multiple `content-type` headers are provided by the request.

  This error should result in a http 400 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400
  """

  defexception plug_status: 400

  def message(_), do: "multiple content-type headers found"
end

defmodule Apical.Exceptions.InvalidContentTypeError do
  @moduledoc """
  Error raised when the `content-type` header does not parse to a valid
  mimetype string.

  This error should result in a http 400 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400
  """

  defexception [:invalid_string, plug_status: 400]

  def message(error), do: "invalid content-type header provided: #{error.invalid_string}"
end
