defmodule Apical.Validators do
  @moduledoc false

  # module for creating exonerate-based validators. Generates the macro as AST
  # so these validators can be built at compile-time.

  @exonerate_opts ~w(metadata format decoders draft)a

  @spec make_quoted(map, JsonPtr.t(), atom, keyword()) :: [Macro.t()]
  def make_quoted(subschema, pointer, fn_name, opts) do
    resource = Keyword.fetch!(opts, :resource)

    List.wrap(
      if Map.get(subschema, "schema") do
        schema_pointer =
          pointer
          |> JsonPtr.join("schema")
          |> JsonPtr.to_uri()
          |> to_string
          |> String.trim_leading("#")

        should_dump =
          List.wrap(
            if Keyword.get(opts, :dump) === :all or Keyword.get(opts, :dump_validator) do
              {:dump, true}
            end
          )

        opts =
          opts
          |> Keyword.take(@exonerate_opts)
          |> Keyword.put(:entrypoint, schema_pointer)
          |> Keyword.merge(should_dump)

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
