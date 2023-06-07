defmodule Apical.Plugs.RequestBody do
  @behaviour Plug

  alias Plug.Conn

  @impl Plug
  def init(opts) do
    opts |> dbg(limit: 25)
  end

  @impl Plug
  def call(conn, _operations) do
    with {:ok, body, conn} <- Conn.read_body(conn) do
      # NB: this code will change
      body_params = Jason.decode!(body)

      conn
      |> Map.replace!(:body_params, body_params)
      |> Map.update!(:params, &update_params(&1, body_params))
    else
      {:error, _} -> raise "fatal error"
    end
  end

  defp update_params(params, body_params) do
    Map.merge(body_params, params)
  end
end
