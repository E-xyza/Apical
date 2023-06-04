defmodule Apical.Plugs.Path do
  @behaviour Plug

  alias Plug.Conn
  alias Apical.Tools

  def init([module, operation_id, parameters, plug_opts]) do
    Enum.reduce(parameters, %{}, fn parameter = %{"name" => name}, operations_so_far ->
      Tools.assert(
        !parameter["allowEmptyValue"],
        "allowEmptyValue is not supported for parameters due to ambiguity, see https://github.com/OAI/OpenAPI-Specification/issues/1573",
        apical: true
      )

      Tools.assert(parameter["required"], "for parameter #{name} in operationId #{operation_id}: path parameters must be `required: true`")

      operations_so_far
      |> add_if_deprecated(parameter)
      # |> add_type(parameter)
      # |> add_style(parameter)
      # |> add_inner_marshal(parameter)
      # |> add_allow_reserved(parameter)
      # |> add_validations(module, operation_id, parameter)
    end)
  end

  defp add_if_deprecated(operations, %{"deprecated" => true, "name" => name}) do
    Map.update(operations, :deprecated, [name], &[name | &1])
  end

  defp add_if_deprecated(operations, _parameters), do: operations

  def call(conn, operations) do
    conn
    |> warn_deprecated(operations)
    # |> validate(operations)
  end

  defp warn_deprecated(conn, %{deprecated: deprecated}) do
    Enum.reduce(deprecated, conn, fn param, conn ->
      if is_map_key(conn.path_params, param) do
        Conn.put_resp_header(
          conn,
          "warning",
          "299 - the path parameter `#{param}` is deprecated."
        )
      else
        conn
      end
    end)
  end

  defp warn_deprecated(conn, _), do: conn
end
