defmodule Apical.Tools do
  @moduledoc false

  # private tools shared across multiple modules in the Apical library

  @default_content_mapping [{"application/yaml", YamlElixir}, {"application/json", Jason}]
  def decode(string, opts) do
    encoding = Keyword.fetch!(opts, :encoding)

    opts
    |> Keyword.get(:decoders, [])
    |> List.keyfind(encoding, 0, List.keyfind(@default_content_mapping, encoding, 0))
    |> case do
      {_, YamlElixir} -> YamlElixir.read_from_string!(string)
      {_, Jason} -> Jason.decode!(string)
      {_, {module, function}} -> apply(module, function, [string])
      nil -> raise "decoder for #{encoding} not found"
    end
  end

  @spec maybe_dump(Macro.t(), keyword) :: Macro.t()
  def maybe_dump(quoted, opts) do
    if Keyword.get(opts, :dump, false) do
      quoted
      |> Macro.to_string()
      |> IO.puts()

      quoted
    else
      quoted
    end
  end

  @terminating ~w(extra_plugs)a

  def deepmerge(into_list, src_list) when is_list(into_list) do
    Enum.reduce(src_list, into_list, fn
      {key, src_value}, so_far when key in @terminating ->
        if List.keyfind(into_list, key, 0) do
          List.keyreplace(so_far, key, 0, {key, src_value})
        else
          [{key, src_value} | so_far]
        end

      {key, src_value}, so_far ->
        if kv = List.keyfind(into_list, key, 0) do
          {_k, v} = kv
          List.keyreplace(so_far, key, 0, {key, deepmerge(v, src_value)})
        else
          [{key, src_value} | so_far]
        end
    end)
  end

  def deepmerge(_, src), do: src

  def assert(condition, message, opts \\ []) do
    # todo: consider adding jsonschema path information here.
    unless condition do
      explained =
        if opts[:apical] do
          "Your schema violates the Apical requirement #{message}"
        else
          "Your schema violates the OpenAPI requirement #{message}"
        end

      raise CompileError, description: explained
    end
  end
end
