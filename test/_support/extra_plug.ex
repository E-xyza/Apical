defmodule ApicalTest.ExtraPlug do
  @behaviour Plug

  alias Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, []), do: Conn.put_private(conn, :extra_module_plug, "no options")
  def call(conn, [option]), do: Conn.put_private(conn, :extra_module_plug_option, option)
end
