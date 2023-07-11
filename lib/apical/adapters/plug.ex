defmodule Apical.Adapters.Plug do
  @moduledoc false
  def build_path(path) do
    # to get proper plug segregation, we have to create a module for each
    # operation.  In order to name these plugs, we'll use a hash of the
    # version and the operation id.

    module_name = :sha256 |> :crypto.hash("#{path.version}-#{path.operation_id}") |> Base.encode16()
    module_alias = {:__aliases__, [alias: false], [String.to_atom(module_name)]}

    quote do

      defmodule unquote(module_alias) do
      end

    end

    #quote do
    #  unquote(path.parameter_validators)
    #  unquote(path.body_validators)
#
    #  pipeline unquote(path.operation_pipeline) do
    #    unquote(path.extra_plugs)
#
    #    plug(Apical.Plugs.SetVersion, unquote(path.version))
    #    plug(Apical.Plugs.SetOperationId, unquote(path.operation_id))
    #    unquote(path.parameter_plugs)
#
    #    unquote(path.body_plugs)
    #  end
#
    #  scope unquote(path.root) do
    #    pipe_through(unquote(path.operation_pipeline))
#
    #    unquote(path.verb)(
    #      unquote(path.canonical_path),
    #      unquote(path.controller),
    #      unquote(path.function)
    #    )
    #  end
    #end
  end
end
