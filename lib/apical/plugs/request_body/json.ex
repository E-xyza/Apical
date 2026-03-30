defmodule Apical.Plugs.RequestBody.Json do
  @moduledoc """
  Source handler for `application/json` request bodies.

  JSON bodies already have proper types from JSON decoding, so marshalling
  is not needed. This handler decodes JSON and validates against the schema.
  """

  alias Apical.Plugs.RequestBody.Source
  @behaviour Source

  @impl true
  def fetch(conn, validator, _marshal_context, opts) do
    # Note: marshal_context is ignored for JSON since Jason.decode
    # already produces proper types (integers, booleans, null, etc.)
    with {:ok, str, conn} <- Source.fetch_body(conn, []),
         {:ok, json} <- Jason.decode(str),
         :ok <- Source.apply_validator(json, validator) do
      {:ok, add_into_params(conn, json, opts)}
    else
      kw_error = {:error, kw} when is_list(kw) ->
        kw_error

      {:error, exception} when is_exception(exception) ->
        {:error, message: " (#{Exception.message(exception)})"}

      {:error, other} ->
        {:error, message: "fetching json body failed: #{other}"}
    end
  end

  defp add_into_params(conn, json, opts) when is_map(json) do
    if Keyword.get(opts, :nest_all_json, false) do
      %{conn | params: Map.put(conn.params, "_json", json)}
    else
      # note that in this case we are merging the params into the json.
      # this is so that someone can't override a declared parameter by
      # supplying a json key unspecified in the schema, that happens to
      # collide with one of the schema-parsed parameters
      %{conn | params: Map.merge(json, conn.params)}
    end
  end

  defp add_into_params(conn, json, _) do
    # when it's not an object, put in under the _json key, this follows the
    # convention set out in phoenix.
    %{conn | params: Map.put(conn.params, "_json", json)}
  end

  @impl true
  def validate!(_, _), do: :ok
end
