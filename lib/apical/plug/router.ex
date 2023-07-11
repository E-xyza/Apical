defmodule Apical.Plug.Router do
  defmacro __using__(opts) do
    quote do
      import Apical.Plug.Router, only: [match: 2]

      @before_compile unquote(__MODULE__)

      # This MUST come after @before_compile, or else the list of
      # operations won't be done.
      use Plug.Builder, unquote(opts)
    end
  end

  def match(conn, _opts) do
    Plug.Conn.send_resp(conn, 404, "not found")
  end

  defmacro __before_compile__(env) do
    env.module
    |> Module.get_attribute(:operations)
    |> List.insert_at(0, :match)
    |> Enum.reverse()
    |> Enum.map(fn
      {:operation, operation_module} ->
        quote do
          plug(Module.concat(__MODULE__, unquote(operation_module)))
        end

      plug ->
        quote do
          plug(unquote(plug))
        end
    end)
  end
end
