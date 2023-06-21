defmodule Apical.Plugs.RequestBody.FormEncoded do
  @moduledoc false

  alias Apical.Plugs.RequestBody.Source
  @behaviour Source

  @impl true
  def fetch(conn, validator, _opts) do
    with {:ok, str, conn} <- Source.fetch_body(conn, string: true),
         params = Plug.Conn.Query.decode(str, %{}, true),
         :ok <- Source.apply_validator(params, validator) do
      {:ok, %{conn | params: Map.merge(params, conn.params)}}
    end
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
