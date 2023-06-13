defmodule Apical do
  alias Apical.Tools

  defmacro router_from_string(string, opts) do
    opts = opts
    |> Macro.expand_literals(__CALLER__)
    |> normalize_opts()

    string
    |> Tools.decode(opts)
    |> Apical.Phoenix.router(string, opts)
    |> Tools.maybe_dump(opts)
  end

  defp normalize_opts(opts) do
    Enum.map(opts, fn {k, v} -> {k, normalize_opts(k, v)} end)
  end

  defp normalize_opts(:controller, module) when is_atom(module) do
    [default: module]
  end

  defp normalize_opts(:controller, keyword) when is_list(keyword) do
    Enum.map(keyword, fn
      atom when is_atom(atom) -> {:default, atom}
      {k, v} -> {k, v}
    end)
  end

  defp normalize_opts(_k, v), do: v
end
