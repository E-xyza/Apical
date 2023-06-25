defmodule Apical.Plugs.SetOperationId do
  @moduledoc """
  `Plug` module which sets the private `:operation_id` key on the `conn` struct
  to the operationId (as an atom) that was declared in the schema.
  """

  @behaviour Plug

  alias Plug.Conn

  @doc false
  def init(operation_id), do: operation_id

  @doc false
  def call(conn, operation_id) do
    Conn.put_private(conn, :operation_id, operation_id)
  end
end
