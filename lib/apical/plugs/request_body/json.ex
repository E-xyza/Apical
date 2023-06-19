defmodule Apical.Plugs.RequestBody.Json do
  alias Apical.Plugs.RequestBody.Source
  @behaviour Source

  @impl true
  def fetch(conn, _opts) do
    with {:ok, str, conn} <- Source.fetch_body(conn, []),
         {:ok, json} <- Jason.decode(str) do
      {:ok, conn, json}
    end
  end
end
