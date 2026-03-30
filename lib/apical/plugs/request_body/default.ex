defmodule Apical.Plugs.RequestBody.Default do
  @moduledoc """
  Default source handler for request bodies with wildcard media types.

  This is a pass-through handler that doesn't process the body.
  """

  @behaviour Apical.Plugs.RequestBody.Source

  @impl true
  def fetch(conn, _validator, _marshal_context, _opts), do: {:ok, conn}

  @impl true
  def validate!(_, _), do: :ok
end
