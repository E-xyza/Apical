defmodule Apical do
  alias Apical.Tools

  defmacro router_from_string(string, opts) do
    string
    |> Tools.decode(opts)
    |> Apical.Phoenix.router(opts)
    |> Tools.maybe_dump(opts)
  end
end
