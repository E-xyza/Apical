defmodule Apical.Plugs.SetOperationId do
  @behaviour Plug

  alias Plug.Conn

  def init(operation_id), do: operation_id

  def call(conn, operation_id) do
    Conn.put_private(conn, :operation_id, operation_id)
  end
end
