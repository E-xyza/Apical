defmodule Apical.Plugs.SetVersion do
  @behaviour Plug

  alias Plug.Conn

  def init(version), do: version

  def call(conn, version) do
    Conn.assign(conn, :api_version, version)
  end
end
