if Application.compile_env(:apical, :egress_testing, false) do
  defmodule Apical.Exceptions.EgressError do
    @moduledoc """
    Error raised when a *response* body does not conform to the schema declared
    for it in the OpenAPI document.

    This module only exists when egress testing is enabled:

    ```elixir
    config :apical, egress_testing: true
    ```

    This error results in an HTTP 500 (Internal Server Error) status code, not a
    4xx: the request itself was well-formed and has already been handled by the
    time responses are validated, so any side effects it had (database writes,
    for example) have already happened.  A 4xx would tell the client that their
    request was rejected and nothing happened, which would not be true.  The
    fault being reported belongs to the server, which produced a response its
    own schema forbids.

    See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/500
    """

    alias Apical.Exceptions.ParameterError

    @optional_keys ~w(operation_id
    status
    media_type
    absolute_keyword_location
    instance_location
    errors
    error_value
    expected
    matches
    reason
    required
    ref_trace)a

    defexception @optional_keys ++ [plug_status: 500]

    @struct_keys @optional_keys ++ [:plug_status]

    @doc false
    def struct_keys, do: @struct_keys

    def message(exception = %{reason: reason}) when is_binary(reason) do
      "#{prefix(exception)}: #{reason}"
    end

    def message(exception) do
      "#{prefix(exception)}: #{ParameterError.describe_exonerate(exception)}"
    end

    defp prefix(exception) do
      "Egress Error in operation #{exception.operation_id} (#{exception.status} #{exception.media_type})"
    end
  end
end
