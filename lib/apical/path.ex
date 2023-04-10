defmodule Apical.Paths do
  def to_routes({path, methods}, opts) do
    Enum.map(methods, &to_route(path, &1, opts))
  end

  @verb_mapping Map.new(~w(get put post delete options head patch trace)a, &{"#{&1}", &1})
  @verbs Map.keys(@verb_mapping)

  defp to_route(path, {verb, %{"operationId" => operationId}}, opts) when verb in @verbs do
    verb = Map.fetch!(@verb_mapping, verb)
    # TODO: resolve controller using controller options
    controller = opts[:controller]
    # TODO: resolve operationId using operationId options
    function = String.to_atom(operationId)

    quote do
      unquote(verb)(unquote(path), unquote(controller), unquote(function))
    end
  end
end
