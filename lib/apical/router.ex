defmodule Apical.Router do
  @moduledoc false

  alias Apical.Path
  alias Apical.Schema
  alias Apical.Testing
  alias Apical.Tools

  def build(schema, schema_string, opts) do
    %{"info" => %{"version" => version}} = Schema.verify_router!(schema)

    resource = Keyword.get_lazy(opts, :resource, fn -> hash(schema) end)
    encode_opts = Keyword.take(opts, ~w(encoding mimetype_mapping)a)

    route_opts =
      opts
      |> Keyword.merge(
        resource: resource,
        root: resolve_root(version, opts),
        version: version
      )
      |> Testing.set_controller()

    routes =
      "/paths"
      |> JsonPtr.from_path()
      |> JsonPtr.map(schema, &Path.to_plug_routes(&1, &2, &3, schema, route_opts))
      |> Enum.unzip()
      |> paths_to_route

    tests = Testing.build_tests(schema, opts)

    quote do
      require Exonerate
      Exonerate.register_resource(unquote(schema_string), unquote(resource), unquote(encode_opts))

      unquote(external_resource(opts))

      unquote(routes)

      unquote(tests)
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

  defp paths_to_route({routes, operation_ids}) do
    validate_no_duplicate_operation_ids!(operation_ids, MapSet.new())

    Enum.flat_map(routes, &Enum.reverse/1)
  end

  defp validate_no_duplicate_operation_ids!([], _so_far), do: :ok

  defp validate_no_duplicate_operation_ids!([set | rest], so_far) do
    intersection = MapSet.intersection(set, so_far)

    Tools.assert(
      intersection == MapSet.new(),
      "that operationIds are unique: (got more than one `#{Enum.at(intersection, 0)}`)"
    )

    validate_no_duplicate_operation_ids!(rest, MapSet.union(set, so_far))
  end
end
