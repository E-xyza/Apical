defmodule Apical.Paths do
  def to_routes({path, methods}, opts) do
    Enum.map(methods, &to_route(path, &1, opts))
  end

  @verb_mapping Map.new(~w(get put post delete options head patch trace)a, &{"#{&1}", &1})
  @verbs Map.keys(@verb_mapping)

  defp to_route(path, {verb, operation = %{"operationId" => operation_id}}, opts) when verb in @verbs do
    verb = Map.fetch!(@verb_mapping, verb)
    # TODO: resolve controller using controller options
    controller = opts[:controller]
    operation_id = String.to_atom(operation_id)
    # TODO: resolve function using operationId options
    function = operation_id

    quote do
      pipeline unquote(operation_id) do
        unquote(plugs(operation))
      end

      scope unquote(path) do
        pipe_through(unquote(operation_id))
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

  defp plugs(%{"parameters" => parameters}) do
    parameters
    |> Enum.group_by(& &1["in"])
    |> Enum.map(fn {location, parameters} ->
      case Map.fetch(@query_mappings, location) do
        {:ok, plug} ->
          quote do
            plug unquote(plug), unquote(Macro.escape(parameters))
          end

        _ ->
          raise "Unsupported parameter location: #{location}"
      end
    end)
  end

  defp plugs(_), do: []
end
