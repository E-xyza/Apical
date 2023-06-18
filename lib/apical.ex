defmodule Apical do
  alias Apical.Tools

  defmacro router_from_string(string, opts) do
    opts = Macro.expand_literals(opts, __CALLER__)

    string
    |> Tools.decode(opts)
    |> Apical.Phoenix.router(string, opts)
    |> Tools.maybe_dump(opts)
  end

  defmacro router_from_file(file, opts) do
    opts = Macro.expand_literals(opts, __CALLER__)

    string =
      file
      |> Macro.expand(__CALLER__)
      |> File.read!()

    string
    |> Tools.decode(opts)
    |> Apical.Phoenix.router(string, opts ++ [file: file])
    |> Tools.maybe_dump(opts)
  end
end
