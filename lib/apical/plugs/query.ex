defmodule Apical.Plugs.Query do
  @behaviour Plug

  alias Plug.Conn

  def init(parameters) do
    # NOTE: parameter motion already occurs
    Enum.reduce(parameters, %{}, fn parameter, operations ->
      operations
      |> add_if_required(parameter)
    end)
  end

  defp add_if_required(operations, %{"required" => true, "name" => name}) do
    Map.update(operations, :required, [name], &[name | &1])
  end
  defp add_if_required(operations, _parameters), do: operations

  def call(conn, operations) do
    conn
    |> Conn.fetch_query_params()
    |> filter_required(operations)
  end

  defp filter_required(conn, %{required: required}) do
    if Enum.all?(required, &is_map_key(conn.params, &1)) do
      conn
    else
      conn
      |> Conn.put_status(400)
      |> Conn.halt()
    end
  end

  defp filter_required(conn, _), do: conn
end
