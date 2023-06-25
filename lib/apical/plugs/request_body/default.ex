defmodule Apical.Plugs.RequestBody.Default do
  @moduledoc """
  """

  @behaviour Apical.Plugs.RequestBody.Source

  @impl true
  def fetch(conn, _validator, _opts), do: {:ok, conn}

  @impl true
  def validate!(_, _), do: :ok
end
