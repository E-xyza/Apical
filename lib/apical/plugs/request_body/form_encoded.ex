defmodule Apical.Plugs.RequestBody.FormEncoded do
  alias Apical.Plugs.RequestBody.Source
  @behaviour Source

  @impl true
  def fetch(conn, _opts) do
    with {:ok, str, conn} <- Source.fetch_body(conn, string: true) do
      # TODO: enable custom module for raising errors
      params = Plug.Conn.Query.decode(str, %{}, true)
      {:ok, %{conn | params: Map.merge(params, conn.params)}}
    end
  end
end
