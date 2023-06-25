defmodule Apical.Plugs.SetVersion do
  @moduledoc """
  `Plug` module which sets the `:api_version` key on the `conn` struct's
  `assigns` to the version string that was declared in the schema.
  """

  @behaviour Plug

  alias Plug.Conn

  @doc false
  def init(version), do: version

  @doc false
  def call(conn, version) do
    Conn.assign(conn, :api_version, version)
  end
end
