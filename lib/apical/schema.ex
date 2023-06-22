defmodule Apical.Schema do
  @moduledoc false

  alias Apical.Tools

  def verify_router!(schema) do
    Tools.assert(is_map_key(schema, "paths"), "the schema has a `paths` key")
  end
end
