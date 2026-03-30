defmodule Apical.Plugs.RequestBody.FormEncoded do
  @moduledoc """
  Source handler for `application/x-www-form-urlencoded` request bodies.

  This handler decodes form-encoded data, marshals string values to their
  proper types based on the schema, and then validates against the schema.
  """

  alias Apical.Plugs.RequestBody.Source
  @behaviour Source

  @impl true
  def fetch(conn, validator, marshal_context, _opts) do
    with {:ok, str, conn} <- Source.fetch_body(conn, string: true),
         params = Plug.Conn.Query.decode(str, %{}, true),
         {:ok, marshalled} <- marshal_params(params, marshal_context),
         :ok <- Source.apply_validator(marshalled, validator) do
      {:ok, %{conn | params: Map.merge(marshalled, conn.params)}}
    else
      kw_error = {:error, kw} when is_list(kw) ->
        kw_error

      {:error, other} ->
        {:error, message: "fetching form-encoded body failed: #{other}"}
    end
  end

  # Marshal form-encoded params to proper types based on schema
  defp marshal_params(params, nil), do: {:ok, params}

  defp marshal_params(params, marshal_context) do
    Source.apply_marshal(params, marshal_context)
  end

  @formencoded_types ["object", ["object"]]

  @impl true
  def validate!(%{"schema" => %{"type" => type}}, operation_id)
      when type not in @formencoded_types do
    type_json = Jason.encode!(type)

    raise CompileError,
      description:
        "media type `application/x-www-form-urlencoded` does not support types other than object, found `#{type_json}` in operation `#{operation_id}`"
  end

  def validate!(_, _), do: :ok
end
