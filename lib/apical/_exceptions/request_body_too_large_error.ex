defmodule Apical.Exceptions.RequestBodyTooLargeError do
  @moduledoc """
  Error raised when the request body is too large.  This could be because the
  payload is larger than the maximum allowed size as specified in configuration
  or if the request body size doesn't match the `content-length` header.

  This error should result in a http 413 status code.
  see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/413
  """

  defexception [:max_length, :content_length, plug_status: 413]

  def message(_), do: "missing content-length header"
end
