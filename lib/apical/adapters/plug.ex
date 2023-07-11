defmodule Apical.Adapters.Plug do
  @moduledoc false
  def build_path(path) do
    quote do
      unquote(path.parameter_validators)
      unquote(path.body_validators)

      pipeline unquote(path.operation_pipeline) do
        unquote(path.extra_plugs)

        plug(Apical.Plugs.SetVersion, unquote(path.version))
        plug(Apical.Plugs.SetOperationId, unquote(path.operation_id))
        unquote(path.parameter_plugs)

        unquote(path.body_plugs)
      end

      scope unquote(path.root) do
        pipe_through(unquote(path.operation_pipeline))

        unquote(path.verb)(
          unquote(path.canonical_path),
          unquote(path.controller),
          unquote(path.function)
        )
      end
    end
  end
end
