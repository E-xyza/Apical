defmodule Apical.Phoenix do
  alias Apical.Paths

  def router(openapi = %{"paths" => paths}, schema, opts) do
    name = Keyword.get_lazy(opts, :name, fn -> hash(openapi) end)
    encode_opts = Keyword.take(opts, ~w(content_type mimetype_mapping)a)
    route_opts = Keyword.put(opts, :name, name)
    routes = Enum.flat_map(paths, &Paths.to_routes(&1, route_opts))

    quote do
      require Exonerate
      Exonerate.register_resource(unquote(schema), unquote(name), unquote(encode_opts))

      unquote(routes)
    end
  end

  defp hash(openapi) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary(openapi))
    |> Base.encode16()
  end
end
