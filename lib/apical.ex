defmodule Apical do
  alias Apical.Tools

  @spec router_from_string(String.t(), Keyword.t()) :: any()
  defmacro router_from_string(string, opts) do
    opts = Macro.expand_literals(opts, __CALLER__)

    router(string, opts)
  end

  @spec router_from_string(File.t(), Keyword.t()) :: any()
  defmacro router_from_file(file, opts) do
    opts = Macro.expand_literals(opts, __CALLER__)

    file
    |> Macro.expand(__CALLER__)
    |> File.read!()
    |> router(opts ++ [file: file])
  end

  defp router(string, opts) do
    string
    |> Tools.decode(opts)
    |> Apical.Phoenix.router(string, opts)
    |> Tools.maybe_dump(opts)
  end
end
