defmodule Apical.Plug.Controller do
  defmacro __using__(_) do
    quote do
      @behaviour Plug

      @impl Plug
      def init(function), do: [function]

      @impl Plug
      def call(conn, [function]) do
        __MODULE__
        |> apply(function, [conn, conn.params])
        |> Plug.Conn.halt()
      end
    end
  end
end
