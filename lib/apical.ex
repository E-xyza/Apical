defmodule Apical do
  alias Apical.Tools

  defmacro router_from_string(string, opts) do
    opts = Macro.expand_literals(opts, __CALLER__)

    string
    |> Tools.decode(opts)
    |> Apical.Phoenix.router(string, opts)
    |> Tools.maybe_dump(opts)
  end
end
