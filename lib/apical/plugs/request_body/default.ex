defmodule Apical.Plugs.RequestBody.Default do
  @behaviour Apical.Plugs.RequestBody.Source

  @impl true
  def fetch(conn, _opts), do: {:ok, conn}
end
