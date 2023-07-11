defmodule Apical.Plug.Router do
  @moduledoc """
  boilerplate code setting up a router using the `Plug`
  framework *without* using `Phoenix`.  Note that although
  this reduces the needed dependencies, this doesn't provide
  you with some Phoenix affordances such as route helpers.
  """

  defmacro __using__(opts) do
    quote do
      import Apical.Plug.Router, only: [match: 2]

      @before_compile unquote(__MODULE__)

      # This MUST come after @before_compile, or else the list of
      # operations won't be done.
      use Plug.Builder, unquote(opts)
    end
  end

  @doc """
  returns a 404 error since none of the routes have matched
  """
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
