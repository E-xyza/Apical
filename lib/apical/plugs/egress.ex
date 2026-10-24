if Application.compile_env(:apical, :egress_testing, false) do
  defmodule Apical.Plugs.Egress do
    @moduledoc """
    `Plug` module for validating *response* bodies against the schemas declared
    for them in the OpenAPI document.

    This module only exists when egress testing is enabled:

    ```elixir
    config :apical, egress_testing: true
    ```

    Because the flag is read with `Application.compile_env/3`, neither this plug
    nor the validators it calls are compiled into a router when it is false.
    Generally it should only be set in the `:test` environment.

    ### init options

    `[router_module, operation_id, validators]`

    where `validators` is a map of `{status_string, media_type} => function_name`
    naming the Exonerate validator for that response, as emitted by `make/4`.

    ### behaviour

    The plug registers a `Plug.Conn.register_before_send/2` callback, so the
    response is validated after the controller has built it but *before* any of
    it reaches the wire.  Raising from there therefore cannot produce a
    half-sent response.

    A response whose body does not conform to its schema raises
    `Apical.Exceptions.EgressError`, which carries a 500 status.  See that
    module for why the status is 5xx and not 4xx.

    Responses with no schema declared for their status code and content type are
    passed through unvalidated, as are bodies that are not valid JSON (there is
    nothing to check them against).
    """

    @behaviour Plug

    alias Apical.Exceptions.EgressError
    alias Plug.Conn

    @impl Plug
    def init([module, operation_id, validators]) do
      %{module: module, operation_id: operation_id, validators: validators}
    end

    @impl Plug
    def call(conn, operations) do
      Conn.register_before_send(conn, &validate_response(&1, operations))
    end

    defp validate_response(conn, operations) do
      with {:ok, validator} <- fetch_validator(conn, operations),
           {:ok, decoded} <- decode(conn.resp_body) do
        apply_validator(conn, validator, operations, decoded)
      else
        :error -> conn
      end
    end

    # a response is keyed by its status code and its content type; fall back to
    # the `default` response object, as the OpenAPI spec allows.
    defp fetch_validator(conn, %{validators: validators}) do
      media_type = response_media_type(conn)
      status = to_string(conn.status)

      with :error <- Map.fetch(validators, {status, media_type}),
           :error <- Map.fetch(validators, {"default", media_type}) do
        :error
      end
    end

    defp response_media_type(conn) do
      conn
      |> Conn.get_resp_header("content-type")
      |> List.first()
      |> case do
        nil ->
          nil

        header ->
          case Conn.Utils.media_type(header) do
            {:ok, type, subtype, _params} -> "#{type}/#{subtype}"
            :error -> nil
          end
      end
    end

    # only JSON bodies can be checked against a JSON schema.  A body that does
    # not decode is not a validation failure -- there is nothing to validate it
    # against -- so it passes through.
    defp decode(body) when is_binary(body) do
      case Jason.decode(body) do
        {:ok, decoded} -> {:ok, decoded}
        {:error, _} -> :error
      end
    end

    defp decode(_), do: :error

    defp apply_validator(conn, validator, operations, decoded) do
      case apply(operations.module, validator, [decoded]) do
        :ok ->
          conn

        {:error, error_fields} ->
          raise EgressError,
                error_fields
                |> Keyword.take(EgressError.struct_keys())
                |> Keyword.merge(
                  operation_id: operations.operation_id,
                  status: conn.status,
                  media_type: response_media_type(conn)
                )
      end
    end

    ###########################################################################
    ## Build egress plug AST.  To be called at compilation step.

    alias Apical.Validators

    @spec make(JsonPtr.t(), schema :: map(), operation_id :: String.t(), plug_opts :: keyword()) ::
            {Macro.t() | nil, [Macro.t()]}
    def make(pointer, schema, operation_id, plug_opts) do
      responses_pointer = JsonPtr.join(pointer, "responses")

      with {:ok, responses} when is_map(responses) <-
             JsonPtr.resolve_json(schema, responses_pointer),
           {validators, validator_asts} when validators != %{} <-
             build_validators(responses, responses_pointer, schema, operation_id, plug_opts) do
        plug =
          quote do
            plug(
              Apical.Plugs.Egress,
              [__MODULE__] ++ unquote([operation_id, Macro.escape(validators)])
            )
          end

        {plug, List.flatten(validator_asts)}
      else
        _ -> {nil, []}
      end
    end

    defp build_validators(responses, responses_pointer, schema, operation_id, plug_opts) do
      version = Keyword.fetch!(plug_opts, :version)

      responses
      |> Enum.flat_map(fn {status, response} ->
        response_pointer = JsonPtr.join(responses_pointer, status)

        {response, response_pointer} = resolve_ref(response, response_pointer, schema)

        case response do
          %{"content" => content} when is_map(content) ->
            Enum.map(content, fn {media_type, _content_schema} ->
              {status, media_type, JsonPtr.join(response_pointer, ["content", media_type])}
            end)

          _ ->
            []
        end
      end)
      |> Enum.reduce({%{}, []}, fn {status, media_type, content_pointer}, {validators, asts} ->
        content_schema = JsonPtr.resolve_json!(schema, content_pointer)

        fn_name = validator_name(version, operation_id, status, media_type)

        case Validators.make_quoted(content_schema, content_pointer, fn_name, plug_opts) do
          [] ->
            {validators, asts}

          ast ->
            {Map.put(validators, {status, media_type}, fn_name), [ast | asts]}
        end
      end)
    end

    defp resolve_ref(%{"$ref" => ref}, _pointer, schema) do
      pointer = JsonPtr.from_uri(ref)
      {JsonPtr.resolve_json!(schema, pointer), pointer}
    end

    defp resolve_ref(response, pointer, _schema), do: {response, pointer}

    def validator_name(version, operation_id, status, media_type) do
      :"#{version}-egress-#{operation_id}-#{status}-#{media_type}"
    end
  end
end
