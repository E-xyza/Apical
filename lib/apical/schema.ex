defmodule Apical.Schema do
  @moduledoc false

  alias Apical.Tools

  @openapi_versions ["3.1.0"]

  def verify_router!(schema) do
    Tools.assert(is_map_key(schema, "paths"), "that the schema has a `paths` key")

    Tools.assert(is_map_key(schema, "openapi"), "that the schema has an `openapi` key")

    openapi = Map.fetch!(schema, "openapi")

    Tools.assert(
      openapi in @openapi_versions,
      "that the schema has a supported `openapi` version (got `#{openapi}`)",
      apical: true
    )

    Tools.assert(is_map_key(schema, "info"), "that the schema has an `info` key")

    Tools.assert(
      is_map_key(schema["info"], "version"),
      "that the schema `info` field has a `version` key"
    )

    schema
  end
end
