defmodule Apical.Plugs.RequestBody.Default do
  @behaviour Apical.Plugs.RequestBody.Source

  @impl true
  def fetch(conn, _opts), do: {:ok, conn}

  @impl true
  def validate!(_, _), do: :ok
end
