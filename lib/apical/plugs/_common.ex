defmodule Apical.Plugs.Common do
  @moduledoc false

  # common functions for plugs to use generally
  alias Plug.Conn
  alias Apical.Tools
  alias Apical.Plugs.Query
  alias Apical.Plugs.Parameter

  def init([in_, module, version, operation_id, parameters, plug_opts]) do
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

      Tools.assert(
        in_ == Query or !parameter["allowReserved"],
        "allowReserved is only supported for query parameters"
      )

      operations_so_far
      |> Map.update!(:parser_context, &Map.put(&1, name, %{}))
      |> add_if_required(parameter)
      |> add_if_deprecated(parameter)
      |> add_type(parameter)
      |> add_style(in_, parameter)
      |> add_inner_marshal(parameter)
      |> add_allow_reserved(parameter)
      |> add_validations(module, version, operation_id, parameter)
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

  defp add_style(operations, in_, parameter = %{"style" => "deepObject", "name" => name}) do
    Tools.assert(
      in_ == Query,
      "for parameter `#{name}` deepObject style is only supported for query parameters"
    )

    Tools.assert(
      parameter["explode"] === true,
      "for parameter `#{name}` deepObject style requires `explode: true`"
    )

    update_in(operations, [:parser_context, :deep_object_keys], &[name | List.wrap(&1)])
  end

  @collection_types [
    "array",
    "object",
    ["array"],
    ["object"],
    ["null", "array"],
    ["null", "object"]
  ]

  defp add_style(operations, in_, parameters = %{"name" => name, "schema" => %{"type" => types}})
       when types in @collection_types do
    types = List.wrap(types)

    collection =
      cond do
        "array" in types -> :array
        "object" in types -> :object
        true -> nil
      end

    explode? = Map.get(parameters, "explode")

    case Map.get(parameters, "style", in_.default_style()) do
      "form" when explode? in [nil, true] ->
        Tools.assert(
          in_.style_allowed?("form"),
          "form style is not allowed for #{in_.name()} parameters"
        )

        Tools.assert(
          collection in [:array, :object],
          "for parameter `#{name}`, default (exploded) style requires schema type array or object.  Consider setting `explode: false`",
          apical: true
        )

        update_in(
          operations,
          [:parser_context, :exploded_array_keys],
          &[name | List.wrap(&1)]
        )

      style ->
        Tools.assert(
          in_.style_allowed?(style),
          "#{style} style is not allowed for #{in_.name()} parameters"
        )

        apply_style(operations, name, style, explode?)
    end
  end

  defp add_style(operations, in_, %{"name" => name, "style" => style})
       when style in ~w(matrix label) do
    Tools.assert(
      in_.style_allowed?(style),
      "#{style} style is not allowed for #{in_.name()} parameters"
    )

    apply_style(operations, name, style, false)
  end

  defp add_style(operations, _in_, parameters = %{"name" => name}) do
    style = parameters["style"]

    Tools.assert(
      is_nil(style),
      "for parameter #{name} the default style #{style} is not supported because the schema type must be a collection.",
      apical: true
    )

    operations
  end

  @style_atom %{
    "form" => :comma_delimited,
    "simple" => :comma_delimited,
    "label" => :label,
    "matrix" => :matrix,
    "spaceDelimited" => :space_delimited,
    "pipeDelimited" => :pipe_delimited
  }

  @explodable ~w(form simple label matrix)

  defp apply_style(operations, name, style, explode?) do
    unless style in @explodable do
      Tools.assert(
        !explode?,
        "for parameter `#{name}`, #{style} style may not be `explode: true`."
      )
    end

    operations
    |> put_in(
      [:parser_context, name, :style],
      Map.fetch!(@style_atom, style)
    )
    |> apply_explode(name, explode?)
  end

  defp apply_explode(operations, name, explode?) do
    if explode? do
      put_in(operations, [:parser_context, name, :explode], true)
    else
      operations
    end
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

  defp add_validations(operations, module, version, operation_id, %{
         "schema" => _schema,
         "name" => name
       }) do
    fun = {module, Apical.Plugs.Parameter.validator_name(version, operation_id, name)}

    Map.update(operations, :validations, %{name => fun}, &Map.put(&1, name, fun))
  end

  defp add_validations(operations, _, _, _, _), do: operations

  # TODO: refactor this into a recursive call
  def filter_required(conn, params, _in_, %{required: required}) do
    if Enum.all?(required, &is_map_key(params, &1)) do
      conn
    else
      # TODO: raise so that this message can be customized
      conn
      |> Conn.put_status(400)
      |> Conn.halt()
    end
  end

  def filter_required(conn, _, _, _), do: conn

  def warn_deprecated(conn, params, in_, %{deprecated: deprecated}) do
    Enum.reduce(deprecated, conn, fn param, conn ->
      if is_map_key(params, param) do
        Conn.put_resp_header(
          conn,
          "warning",
          "299 - the #{in_} parameter `#{param}` is deprecated."
        )
      else
        conn
      end
    end)
  end

  def warn_deprecated(conn, _, _, _), do: conn

  def validate(conn, params, in_, %{validations: validation_map}) do
    Enum.reduce(validation_map, conn, fn
      {param, {mod, fun}}, conn ->
        with {:ok, content} <- Map.fetch(params, param),
             :ok <- apply(mod, fun, [content]) do
          conn
        else
          :error ->
            conn

          {:error, reasons} ->
            raise Apical.Exceptions.ParameterError,
                  [operation_id: conn.private.operation_id, in: in_] ++ reasons
        end
    end)
  end

  def validate(conn, _, _, _), do: conn
end
