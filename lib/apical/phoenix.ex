defmodule Apical.Phoenix do
  alias Apical.Paths
  alias Apical.Schema

  def router(openapi = %{"info" => %{"version" => version}, "paths" => paths}, schema, opts) do
    Schema.verify_schema_basics!(openapi)

    name = Keyword.get_lazy(opts, :name, fn -> hash(openapi) end)
    encode_opts = Keyword.take(opts, ~w(content_type mimetype_mapping)a)
    route_opts = Keyword.put(opts, :name, name)

    root = resolve_root(version, opts)
    routes = Enum.flat_map(paths, &Paths.to_routes(root, &1, version, route_opts))

    quote do
      require Exonerate
      Exonerate.register_resource(unquote(schema), unquote(name), unquote(encode_opts))

      unquote(external_resource(opts))

      unquote(routes)
    end
  end

  defp external_resource(opts) do
    List.wrap(
      if file = Keyword.get(opts, :file) do
        quote do
          @external_resource unquote(file)
        end
      end
    )
  end

  defp hash(openapi) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary(openapi))
    |> Base.encode16()
  end

  defp resolve_root(version, opts) do
    case Keyword.fetch(opts, :root) do
      {:ok, root} -> root
      :error -> resolve_version(version)
    end
  end

  defp resolve_version(version) do
    case String.split(version, ".") do
      [a, _ | _rest] ->
        "/v#{a}"

      _ ->
        raise CompileError,
          description: """
          unable to parse supplied version string `#{version}` into a default root path.

          Suggested resolutions:
          - supply root path using `root: <path>` option
          - use semver version in `info` -> `version` in schema.
          """
    end
  end
end
