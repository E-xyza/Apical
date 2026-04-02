defmodule Apical.Exceptions.NotAcceptableError do
  @moduledoc """
  Error raised when the client's `Accept` header does not match any of the
  response content types defined in the OpenAPI schema.

  This error results in an HTTP 406 (Not Acceptable) status code.
  See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/406
  """

  defexception [:operation_id, :accept, :available, plug_status: 406]

  def message(error) do
    available = Enum.join(error.available, ", ")
    "Accept header `#{error.accept}` does not match available content types: #{available}"
  end
end
