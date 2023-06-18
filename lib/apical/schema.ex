defmodule Apical.Schema do
  @moduledoc false

  alias Apical.Tools

  def verify_schema_basics!(%{"paths" => paths}) do
    Enum.reduce(paths, MapSet.new(), &verify_operation_id_path/2)
  end

  def verify_operation_id_path({path, verbs}, set) do
    Enum.reduce(verbs, set, &verify_operation_id_verb(path, &1, &2))
  end

  defp verify_operation_id_verb(_path, {_verb, %{"operationId" => name}}, so_far) do
    Tools.assert(
      name not in so_far,
      "that operationIds are unique: (got more than one `#{name}`)"
    )

    MapSet.put(so_far, name)
  end

  defp verify_operation_id_verb(path, {verb, _}, _) do
    path =
      "/"
      |> JsonPtr.from_path()
      |> JsonPtr.join(["paths", path, verb])
      |> JsonPtr.to_path()

    Tools.assert(
      false,
      "that all operations have an operationId: (missing for operation at `#{path}`)"
    )
  end
end
