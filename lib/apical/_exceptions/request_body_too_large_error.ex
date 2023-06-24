defmodule Apical.Exceptions.RequestBodyTooLargeError do
  defexception [:max_length, :content_length, plug_status: 413]

  def message(_), do: "missing content-length header"
end
