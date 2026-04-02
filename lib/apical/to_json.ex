defprotocol Apical.ToJson do
  @moduledoc """
  Protocol for converting Apical errors to JSON-compatible maps.

  This protocol provides a consistent way to convert Apical exceptions
  to maps that can be easily serialized to JSON for API error responses.

  ## Example

      error = %Apical.Exceptions.ParameterError{
        operation_id: "getUser",
        in: :path,
        reason: "required parameter `id` not present"
      }

      json_map = Apical.ToJson.to_json(error)
      # => %{
      #   error: "parameter_error",
      #   status: 400,
      #   operation_id: "getUser",
      #   location: "path",
      #   message: "Parameter Error in operation getUser (in path): ..."
      # }

      Jason.encode!(json_map)
      # => "{\"error\":\"parameter_error\",\"status\":400,...}"

  """

  @doc """
  Converts an Apical exception to a JSON-compatible map.

  Returns a map with at minimum:
  - `:error` - A string identifier for the error type
  - `:status` - The HTTP status code
  - `:message` - A human-readable error message

  Additional fields may be included depending on the error type.
  """
  @spec to_json(t) :: map()
  def to_json(error)
end

defimpl Apical.ToJson, for: Apical.Exceptions.ParameterError do
  def to_json(error) do
    base = %{
      error: "parameter_error",
      status: error.plug_status,
      message: Exception.message(error)
    }

    base
    |> maybe_add(:operation_id, error.operation_id)
    |> maybe_add(:location, error.in && Atom.to_string(error.in))
    |> maybe_add_details(error)
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  defp maybe_add_details(map, error) do
    details =
      %{}
      |> maybe_add(:value, error.error_value)
      |> maybe_add(:schema_location, error.absolute_keyword_location)
      |> maybe_add(:instance_location, error.instance_location)
      |> maybe_add(:reason, error.reason)

    if map_size(details) > 0 do
      Map.put(map, :details, details)
    else
      map
    end
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.MissingContentTypeError do
  def to_json(error) do
    %{
      error: "missing_content_type",
      status: error.plug_status,
      message: Exception.message(error)
    }
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.MultipleContentTypeError do
  def to_json(error) do
    %{
      error: "multiple_content_type",
      status: error.plug_status,
      message: Exception.message(error)
    }
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.InvalidContentTypeError do
  def to_json(error) do
    %{
      error: "invalid_content_type",
      status: error.plug_status,
      message: Exception.message(error),
      invalid_value: error.invalid_string
    }
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.MissingContentLengthError do
  def to_json(error) do
    %{
      error: "missing_content_length",
      status: error.plug_status,
      message: Exception.message(error)
    }
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.MultipleContentLengthError do
  def to_json(error) do
    %{
      error: "multiple_content_length",
      status: error.plug_status,
      message: Exception.message(error)
    }
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.InvalidContentLengthError do
  def to_json(error) do
    %{
      error: "invalid_content_length",
      status: error.plug_status,
      message: Exception.message(error),
      invalid_value: error.invalid_string
    }
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.RequestBodyTooLargeError do
  def to_json(error) do
    %{
      error: "request_body_too_large",
      status: error.plug_status,
      message: Exception.message(error),
      max_length: error.max_length,
      content_length: error.content_length
    }
  end
end

defimpl Apical.ToJson, for: Apical.Exceptions.NotAcceptableError do
  def to_json(error) do
    %{
      error: "not_acceptable",
      status: error.plug_status,
      message: Exception.message(error),
      operation_id: error.operation_id,
      accept: error.accept,
      available: error.available
    }
  end
end
