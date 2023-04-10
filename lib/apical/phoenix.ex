defmodule Apical.Phoenix do
  alias Apical.Paths
  def router(openapi = %{"paths" => paths}, opts) do
    Enum.flat_map(paths, &Paths.to_routes(&1, opts))
  end
end
