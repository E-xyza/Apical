defmodule Apical.Plug.Router do
  defmacro __using__(_) do
    quote do
      @behaviour Plug

      @impl Plug
      def init(opts) do
        opts
      end

      @impl Plug
      def call(conn, opts) do
        conn
        |> Plug.Conn.send_resp(404, "not found")
      end
    end
  end
end
