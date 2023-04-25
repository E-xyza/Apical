defmodule Apical.Plugs.Query do
  @behaviour Plug

  alias Plug.Conn
  alias Apical.Tools

  def init([module, operation_id, parameters, plug_opts]) do
    # TODO: document what we're doing with query context.
    operations =
      plug_opts
      |> opts_to_context
      |> Map.put(:parser_context, %{})

    Enum.reduce(parameters, operations, fn parameter = %{"name" => name}, operations_so_far ->
      Tools.assert(
        !parameter["allowEmptyValue"],
        "allowEmptyValue is not supported for parameters due to ambiguity, see https://github.com/OAI/OpenAPI-Specification/issues/1573",
        apical: true
      )

      operations_so_far
      |> Map.update!(:parser_context, &Map.put(&1, name, %{}))
      |> add_if_required(parameter)
      |> add_if_deprecated(parameter)
      |> add_type(parameter)
      |> add_style(parameter)
      |> add_inner_marshal(parameter)
      |> add_allow_reserved(parameter)
      |> add_validations(module, operation_id, parameter)
    end)
  end

  defp opts_to_context(plug_opts) do
    Enum.reduce(~w(styles)a, %{}, fn
      :styles, so_far ->
        if styles = Keyword.get(plug_opts, :styles) do
          Map.put(so_far, :styles, Map.new(styles))
        else
          so_far
        end
    end)
  end

  defp add_if_required(operations, %{"required" => true, "name" => name}) do
    Map.update(operations, :required, [name], &[name | &1])
  end

  defp add_if_required(operations, _parameters), do: operations

  defp add_if_deprecated(operations, %{"deprecated" => true, "name" => name}) do
    Map.update(operations, :deprecated, [name], &[name | &1])
  end

  defp add_if_deprecated(operations, _parameters), do: operations

  defp add_type(operations, %{"name" => name, "schema" => %{"type" => type}}) do
    types = to_type_list(type)

    %{
      operations
      | parser_context: Map.update!(operations.parser_context, name, &Map.put(&1, :type, types))
    }
  end

  defp add_type(operations, _), do: operations

  @types ~w(null boolean integer number string array object)a
  @type_class Map.new(@types, &{"#{&1}", &1})
  @type_order Map.new(Enum.with_index(@types))

  defp to_type_list(type) do
    type
    |> List.wrap()
    |> Enum.map(&Map.fetch!(@type_class, &1))
    |> Enum.sort_by(&Map.fetch!(@type_order, &1))
  end

  defp add_style(operations, parameter = %{"style" => "deepObject", "name" => name}) do
    Tools.assert(
      parameter["explode"] === true,
      "for parameter `#{name}` deepObject style requires `explode: true`"
    )

    update_in(operations, [:parser_context, :deep_object_keys], &[name | List.wrap(&1)])
  end

  @default_styles ~w(form spaceDelimited pipeDelimited deepObject)

  defp add_style(operations, parameter = %{"style" => style}) when style not in @default_styles do
    descriptor = get_in(operations, [:styles, style])

    new_parser_context =
      Map.update(
        operations.parser_context,
        parameter["name"],
        %{style: descriptor},
        &Map.put(&1, :style, descriptor)
      )

    %{operations | parser_context: new_parser_context}
  end

  @collection_types [
    "array",
    "object",
    ["array"],
    ["object"],
    ["null", "array"],
    ["null", "object"]
  ]

  defp add_style(operations, parameters = %{"name" => name, "schema" => %{"type" => types}})
       when types in @collection_types do
    types = List.wrap(types)

    collection =
      cond do
        "array" in types -> :array
        "object" in types -> :object
        true -> nil
      end

    case Map.fetch(parameters, "style") do
      :error ->
        # default style is "form"

        case parameters["explode"] do
          default when default in [nil, true] ->
            Tools.assert(
              collection === :array,
              "for parameter `#{name}`, default (exploded) style requires schema type array.  Consider setting `explode: false`",
              apical: true
            )

            update_in(
              operations,
              [:parser_context, :exploded_array_keys],
              &[name | List.wrap(&1)]
            )

          false ->
            put_in(
              operations,
              [:parser_context, name, :style],
              :comma_delimited
            )
        end

      {:ok, "form"} ->
        case parameters["explode"] do
          default when default in [nil, true] ->
            Tools.assert(
              collection === :array,
              "for parameter `#{name}`, form (exploded) style requires schema type array.  Consider setting `explode: false`",
              apical: true
            )

            update_in(
              operations,
              [:parser_context, :exploded_array_keys],
              &[name | List.wrap(&1)]
            )

          false ->
            put_in(
              operations,
              [:parser_context, name, :style],
              :comma_delimited
            )
        end

      {:ok, "spaceDelimited"} ->
        Tools.assert(
          not Map.get(parameters, "explode", false),
          "for parameter `#{name}`, spaceDelimited style may not be `explode: true`.",
          apical: true
        )

        put_in(
          operations,
          [:parser_context, name, :style],
          :space_delimited
        )

      {:ok, "pipeDelimited"} ->
        Tools.assert(
          not Map.get(parameters, "explode", false),
          "for parameter `#{name}`, pipeDelimited style may not be `explode: true`.",
          apical: true
        )

        put_in(
          operations,
          [:parser_context, name, :style],
          :pipe_delimited
        )
    end
  end

  defp add_style(operations, parameters = %{"name" => name}) do
    style = parameters["style"]

    Tools.assert(
      is_nil(style),
      "for parameter #{name} the default style #{style} is not supported because the schema type must be a collection.",
      apical: true
    )

    operations
  end

  defp add_inner_marshal(operations = %{parser_context: context}, %{
         "schema" => schema,
         "name" => key
       })
       when is_map_key(context, key) do
    outer_type = context[key].type

    cond do
      :array in outer_type ->
        prefix_items_type =
          case schema do
            %{"prefixItems" => prefix_items} ->
              Enum.map(prefix_items, &to_type_list(&1["type"] || ["string"]))


            %{"items" => items} ->
              Enum.map(items, &to_type_list(&1["type"] || ["string"]))

            _ ->
              []
          end

        items_type =
          case schema do
            %{"items" => items} when is_map(items) ->
              to_type_list(items["type"] || ["string"])

            %{"additionalItems" => additional_items} ->
              to_type_list(additional_items["type"] || ["string"])

            _ ->
              []
          end

        new_key_spec =
          Map.put(operations.parser_context[key], :elements, {prefix_items_type, items_type})

        put_in(operations, [:parser_context, key], new_key_spec)

      :object in outer_type ->
        property_types =
          schema
          |> Map.get("properties", %{})
          |> Map.new(fn {name, property} ->
            {name, to_type_list(property["type"])}
          end)

        pattern_types =
          schema
          |> Map.get("patternProperties", %{})
          |> Map.new(fn {regex, property} ->
            {Regex.compile!(regex), to_type_list(property["type"])}
          end)

        additional_types =
          schema
          |> get_in(["additionalProperties", "type"])
          |> Kernel.||("string")
          |> to_type_list()

        new_key_spec =
          Map.put(
            operations.parser_context[key],
            :properties,
            {property_types, pattern_types, additional_types}
          )

        put_in(operations, [:parser_context, key], new_key_spec)

      true ->
        operations
    end
  end

  defp add_inner_marshal(operations, _), do: operations

  defp add_allow_reserved(operations, %{"name" => name, "allowReserved" => true}) do
    put_in(operations, [:parser_context, name, :allow_reserved], true)
  end

  defp add_allow_reserved(operations, _), do: operations

  defp add_validations(operations, module, operation_id, %{"schema" => _schema, "name" => name}) do
    fun = {module, :"#{operation_id}-#{name}"}

    Map.update(operations, :validations, %{name => fun}, &Map.put(&1, name, fun))
  end

  defp add_validations(operations, _, _, _), do: operations

  # CALL.  This code runs all of those things that we so painstakingly compiled, up above.

  def call(conn, operations) do
    # TODO: refactor this out to the outside.
    conn
    |> Apical.Conn.fetch_query_params(operations.parser_context)
    |> filter_required(operations)
    |> warn_deprecated(operations)
    |> validate(operations)
  end

  defp filter_required(conn, %{required: required}) do
    if Enum.all?(required, &is_map_key(conn.query_params, &1)) do
      conn
    else
      # TODO: raise so that this message can be customized
      conn
      |> Conn.put_status(400)
      |> Conn.halt()
    end
  end

  defp filter_required(conn, _), do: conn

  defp warn_deprecated(conn, %{deprecated: deprecated}) do
    Enum.reduce(deprecated, conn, fn param, conn ->
      if is_map_key(conn.query_params, param) do
        Conn.put_resp_header(
          conn,
          "warning",
          "299 - the query parameter `#{param}` is deprecated."
        )
      else
        conn
      end
    end)
  end

  defp warn_deprecated(conn, _), do: conn

  defp validate(conn, %{validations: validation_map}) do
    Enum.reduce(validation_map, conn, fn
      {param, {mod, fun}}, conn ->
        with {:ok, content} <- Map.fetch(conn.query_params, param),
             :ok <- apply(mod, fun, [content]) do
          conn
        else
          :error ->
            conn

          {:error, reasons} ->
            raise Apical.Exceptions.ParameterError,
                  [operation_id: conn.private.operation_id, in: :query] ++ reasons
        end
    end)
  end

  defp validate(conn, _), do: conn
end
