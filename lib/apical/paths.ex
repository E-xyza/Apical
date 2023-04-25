defmodule Apical.Paths do
  def to_routes({path, methods}, opts) do
    base_pointer =
      "/paths"
      |> JsonPointer.from_path()
      |> JsonPointer.join(path)

    Enum.map(methods, &to_route(path, &1, base_pointer, opts))
  end

  @verb_mapping Map.new(~w(get put post delete options head patch trace)a, &{"#{&1}", &1})
  @verbs Map.keys(@verb_mapping)

  defp to_route(path, {verb, operation = %{"operationId" => operation_id}}, base_pointer, opts)
       when verb in @verbs do
    verb_pointer = JsonPointer.join(base_pointer, verb)
    verb = Map.fetch!(@verb_mapping, verb)
    # TODO: resolve controller using controller options
    controller = opts[:controller]
    operation_pipeline = String.to_atom(operation_id)
    # TODO: resolve function using operationId options
    function = String.to_atom(operation_id)

    plug_opts = Keyword.take(opts, [:styles])

    # generate exonerate validators.
    validators =
      operation
      |> Map.get("parameters")
      |> List.wrap()
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {subschema, index} ->
          pointer = JsonPointer.join(verb_pointer, ["parameters", "#{index}"])
          validators(subschema, Keyword.fetch!(opts, :name), pointer, operation_id, opts)
      end)

    quote do
      unquote(validators)

      pipeline unquote(operation_pipeline) do
        plug(Apical.Plugs.SetOperationId, unquote(operation_pipeline))
        unquote(plugs(operation, plug_opts))
      end

      scope unquote(path) do
        pipe_through(unquote(operation_pipeline))
        unquote(verb)("/", unquote(controller), unquote(function))
      end
    end
  end

  @query_mappings %{
    "query" => Apical.Plugs.Query,
    "header" => Apical.Plugs.Header,
    "path" => Apical.Plugs.Path,
    "cookie" => Apical.Plugs.Cookie
  }

  defp plugs(%{"parameters" => parameters, "operationId" => operation_id}, plug_opts) do
    parameters
    |> Enum.group_by(& &1["in"])
    |> Enum.map(fn {location, parameters} ->
      case Map.fetch(@query_mappings, location) do
        {:ok, plug} ->
          quote do
            plug(
              unquote(plug),
              [__MODULE__] ++ unquote([operation_id, Macro.escape(parameters), plug_opts])
            )
          end

        _ ->
          raise "Unsupported parameter location: #{location}"
      end
    end)
  end

  defp plugs(_, _), do: []

  defp validators(parameter = %{"name" => name}, resource, pointer, operation_id, opts) do
    fn_name = :"#{operation_id}-#{name}"

    List.wrap(
      if Map.get(parameter, "schema") do
        schema_pointer =
          pointer
          |> JsonPointer.join("schema")
          |> JsonPointer.to_uri()
          |> to_string
          |> String.trim_leading("#")

        opts = Keyword.put(opts, :entrypoint, schema_pointer)

        quote do
          Exonerate.function_from_resource(
            :def,
            unquote(fn_name),
            unquote(resource),
            unquote(opts)
          )
        end
      end
    )
  end
end
