defmodule Apical.Plugs.Parameter do
  @callback name() :: atom()
  @callback default_style() :: String.t()
  @callback style_allowed?(String.t()) :: boolean

  alias Apical.Plugs.Query
  alias Apical.Tools
  alias Apical.Validators
  alias Apical.Exceptions.ParameterError

  alias Plug.Conn

  # common functions for parameter plugs to use generally
  # note that this module is not a plug itself (this is why it's in an
  # underscored file)

  # INITIALIZATION

  def init([in_, module, version, operation_id, parameters, plug_opts]) do
    operations =
      plug_opts
      |> opts_to_context
      |> Map.put(:parser_context, %{})

    Enum.reduce(parameters, operations, fn parameter = %{"name" => name}, operations_so_far ->
      merge_opts =
        plug_opts
        |> Keyword.get(:parameters, [])
        |> Enum.find(&(Atom.to_string(elem(&1, 0)) == name))
        |> List.wrap()

      plug_opts = Tools.deepmerge(plug_opts, merge_opts)

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
      |> add_style(in_, parameter, plug_opts)
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

  @style_to_atom %{
    "form" => :form,
    "simple" => :simple,
    "label" => :label,
    "matrix" => :matrix,
    "spaceDelimited" => :space_delimited,
    "pipeDelimited" => :pipe_delimited
  }

  @explodable ~w(form simple label matrix)

  @builtin_styles Map.keys(@style_to_atom) ++ ["deepObject"]

  @collection_types [
    "array",
    "object",
    ["array"],
    ["object"],
    ["null", "array"],
    ["null", "object"]
  ]

  defp merge_style(opts, name) do
    to_merge =
      opts
      |> Keyword.get(:parameters, [])
      |> Enum.find_value(fn {k, v} ->
        if Atom.to_string(k) == name, do: v
      end)
      |> List.wrap()

    Tools.deepmerge(opts, to_merge)
  end

  defp add_style(operations, _in_, parameter = %{"style" => style, "name" => name}, opts)
       when style not in @builtin_styles do
    opts = merge_style(opts, name)

    with {:ok, styles} <- Keyword.fetch(opts, :styles),
         {_, mf_or_mfa} <- List.keyfind(styles, style, 0) do
      operations
      |> apply_style(name, mf_or_mfa, Map.get(parameter, "explode"))
      |> put_in([:parser_context, name, :style_name], style)
    else
      _ ->
        Tools.assert(
          false,
          "custom style `#{style}` needs to have a definition in the `:styles` option",
          apical: true
        )
    end
  end

  defp add_style(operations, in_, parameter = %{"style" => "deepObject", "name" => name}, _opts) do
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

  defp add_style(
         operations,
         in_,
         parameters = %{"name" => name, "schema" => %{"type" => types}},
         _opts
       )
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
          "for parameter `#{name}`, form (exploded) style requires schema type array or object.  Consider setting `explode: false`",
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

  defp add_style(operations, in_, %{"name" => name, "style" => style}, _opts)
       when style in ~w(matrix label) do
    Tools.assert(
      in_.style_allowed?(style),
      "#{style} style is not allowed for #{in_.name()} parameters"
    )

    apply_style(operations, name, style, false)
  end

  defp add_style(operations, _in_, parameters = %{"name" => name}, _opts) do
    style = parameters["style"]

    Tools.assert(
      is_nil(style),
      "for parameter #{name} the default style #{style} is not supported because the schema type must be a collection.",
      apical: true
    )

    operations
  end

  defp apply_style(operations, name, mf_or_mfa, explode) when is_tuple(mf_or_mfa) do
    explode = List.wrap(explode)

    style =
      case mf_or_mfa do
        {m, f} -> {m, f, explode}
        {m, f, a} -> {m, f, explode ++ a}
      end

    put_in(operations, [:parser_context, name, :style], style)
  end

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
      Map.fetch!(@style_to_atom, style)
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
    outer_type = Map.get(context[key], :type, [])

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
    fun = {module, validator_name(version, operation_id, name)}

    Map.update(operations, :validations, %{name => fun}, &Map.put(&1, name, fun))
  end

  defp add_validations(operations, _, _, _, _), do: operations

  # REQUIRED PARAMETERS

  # TODO: refactor this into a recursive call
  def check_required(conn, params, in_, %{required: required}) do
    Enum.each(required, fn
      parameter when is_map_key(params, parameter) ->
        :ok

      parameter ->
        raise ParameterError,
          operation_id: conn.private.operation_id,
          in: in_,
          reason: "required parameter `#{parameter}` not present"
    end)

    conn
  end

  def check_required(conn, _, _, _), do: conn

  # DEPRECATED PARAMETERS

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

  # VALIDATION STEP

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

  # REFLECTION

  defp validator_name(version, operation_id, name) do
    :"#{version}-#{operation_id}-#{name}"
  end

  # make function: builds plug and validation macros out of the schema.

  @accumulator %{plugs: %{}, validators: [], parameters: MapSet.new()}

  @no_parameters {[], []}

  @spec make(JsonPtr.t(), schema :: map(), operation_id :: String.t(), plug_opts :: keyword()) ::
          {plugs :: [Macro.t()], validations :: [Macro.t()]}
  def make(operation_pointer, schema, operation_id, plug_opts) do
    case JsonPtr.resolve_json!(schema, operation_pointer) do
      %{"parameters" => _} ->
        %{plugs: plugs, validators: validators} =
          operation_pointer
          |> JsonPtr.join("parameters")
          |> JsonPtr.reduce(
            schema,
            @accumulator,
            &do_make(&2, &1, &3, schema, operation_id, plug_opts)
          )

        {Enum.map(plugs, &make_parameter_plug(&1, operation_id, plug_opts)),
         List.flatten(validators)}

      _ ->
        @no_parameters
    end
  end

  @location_modules %{
    "query" => Apical.Plugs.Query,
    "header" => Apical.Plugs.Header,
    "path" => Apical.Plugs.Path,
    "cookie" => Apical.Plugs.Cookie
  }
  @locations Map.keys(@location_modules)

  defp do_make(%{"$ref" => ref}, _parameter_pointer, acc, schema, operation_id, plug_opts) do
    # for now, don't handle remote refs
    pointer = JsonPtr.from_uri(ref)

    schema
    |> JsonPtr.resolve_json!(pointer)
    |> do_make(pointer, acc, schema, operation_id, plug_opts)
  end

  defp do_make(
         subschema = %{"name" => name, "in" => in_},
         parameter_pointer,
         acc,
         _schema,
         operation_id,
         plug_opts
       )
       when in_ in @locations do
    module = Map.fetch!(@location_modules, in_)

    new_validator =
      make_parameter_validator(subschema, parameter_pointer, operation_id, plug_opts)

    Tools.assert(
      name not in acc.parameters,
      "for unique parameters: the parameter `#{name}` is not unique (in operation `#{operation_id}`)"
    )

    %{
      plugs: Map.update(acc.plugs, module, [subschema], &[subschema | &1]),
      validators: [new_validator | acc.validators],
      parameters: MapSet.put(acc.parameters, name)
    }
  end

  defp do_make(%{"in" => non_location}, parameter_pointer, _, _, operation_id, _)
       when non_location not in @locations do
    {_, index} = JsonPtr.pop(parameter_pointer)

    Tools.assert(
      false,
      "for parameters, invalid parameter location: `#{non_location}` (in operation `#{operation_id}`, parameter #{index})"
    )
  end

  defp do_make(parameter, parameter_pointer, _, _, operation_id, _) do
    {_, index} = JsonPtr.pop(parameter_pointer)

    Tools.assert(
      is_map_key(parameter, "in"),
      "for parameters, field `in` is required (in operation `#{operation_id}`, parameter #{index})"
    )

    Tools.assert(
      is_map_key(parameter, "name"),
      "for parameters, field `name` is required (in operation `#{operation_id}`, parameter #{index})"
    )
  end

  defp make_parameter_plug({module, plug_schemas}, operation_id, plug_opts) do
    version = Keyword.fetch!(plug_opts, :version)

    quote do
      plug(
        unquote(module),
        [__MODULE__] ++
          unquote([version, operation_id, Macro.escape(plug_schemas), plug_opts])
      )
    end
  end

  defp make_parameter_validator(subschema = %{"name" => name}, pointer, operation_id, plug_opts) do
    version = Keyword.fetch!(plug_opts, :version)
    fn_name = validator_name(version, operation_id, name)
    Validators.make_quoted(subschema, pointer, fn_name, plug_opts)
  end

  #  defp verify_not_form_exploded_object!(parameter_opts, operation_id) do
  #    Enum.each(parameter_opts, fn
  #      %{
  #        "explode" => true,
  #        "style" => "form",
  #        "schema" => %{"type" => type_or_types},
  #        "name" => name
  #      } ->
  #        Tools.assert(
  #          "object" not in List.wrap(type_or_types),
  #          "for parameter `#{name}` in operation `#{operation_id}`: form exploded parameters may not be objects",
  #          apical: true
  #        )
  #
  #      _ ->
  #        :ok
  #    end)
  #  end
end
