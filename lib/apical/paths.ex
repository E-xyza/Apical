defmodule Apical.Paths do
  # see: https://datatracker.ietf.org/doc/html/rfc6570#section-3.2.3
  #   to understand path expansion rules.

  alias Apical.Plugs.Parameter
  alias Apical.Plugs.RequestBody

  def to_routes(root, {path, methods}, version, opts) do
    base_pointer =
      "/paths"
      |> JsonPtr.from_path()
      |> JsonPtr.join(path)

    Enum.map(methods, &to_route(root, path, &1, base_pointer, version, opts))
  end

  @verb_mapping Map.new(~w(get put post delete options head patch trace)a, &{"#{&1}", &1})
  @verbs Map.keys(@verb_mapping)

  defp to_route(
         root,
         path,
         {verb, operation = %{"operationId" => operation_id}},
         base_pointer,
         version,
         opts
       )
       when verb in @verbs do
    {canonical_path, path_parameters} =
      case path(path, context: %{path_parameters: []}) do
        {:ok, canonical, "", context, _, _} ->
          {"#{canonical}", context.path_parameters}

        _ ->
          raise CompileError, description: "path #{path} is not a valid path template"
      end

    verb_pointer = JsonPtr.join(base_pointer, verb)
    verb = Map.fetch!(@verb_mapping, verb)

    tags = Map.get(operation, "tags", [])
    opts = fold_opts(opts, tags, operation_id)

    operation_pipeline = :"#{version}-#{operation_id}"
    # TODO: resolve function using operationId options
    function = String.to_atom(operation_id)

    plug_opts =
      opts
      |> Keyword.take(~w(styles nest_all_json)a)
      |> Keyword.merge(path_parameters: path_parameters, path: path)

    controller =
      case Keyword.fetch(opts, :controller) do
        {:ok, controller} when is_atom(controller) ->
          controller

        {:ok, controller} ->
          raise CompileError,
            description:
              "invalid controller for operation #{operation_id}, got #{inspect(controller)} (expected a module atom)"

        :error ->
          raise CompileError, description: "can't find controller for operation #{operation_id}"
      end

    # generate exonerate validators.
    parameter_validators =
      operation
      |> Map.get("parameters")
      |> List.wrap()
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {subschema, index} ->
          pointer = JsonPtr.join(verb_pointer, ["parameters", "#{index}"])
          name = Map.fetch!(subschema, "name")
          fn_name = Parameter.validator_name(version, operation_id, name)
          validator(subschema, Keyword.fetch!(opts, :name), pointer, fn_name, opts)
      end)

    body_validators =
      operation
      |> get_in(~w(requestBody content))
      |> Kernel.||([])
      |> Enum.flat_map(fn
        {mimetype, subschema} ->
          pointer = JsonPtr.join(verb_pointer, ["requestBody", "content", mimetype])
          fn_name = RequestBody.validator_name(version, operation_id, mimetype)
          validator(subschema, Keyword.fetch!(opts, :name), pointer, fn_name, opts)
      end)

    quote do
      unquote(parameter_validators)
      unquote(body_validators)

      pipeline unquote(operation_pipeline) do
        plug(Apical.Plugs.SetVersion, unquote(version))
        plug(Apical.Plugs.SetOperationId, unquote(operation_id))
        unquote(parameter_plugs(operation, version, plug_opts))
        unquote(request_body_plugs(operation, version, plug_opts))
      end

      scope unquote(root) do
        pipe_through(unquote(operation_pipeline))
        unquote(verb)(unquote(canonical_path), unquote(controller), unquote(function))
      end
    end
  end

  @query_mappings %{
    "query" => Apical.Plugs.Query,
    "header" => Apical.Plugs.Header,
    "path" => Apical.Plugs.Path,
    "cookie" => Apical.Plugs.Cookie
  }

  defp parameter_plugs(
         %{"parameters" => parameters, "operationId" => operation_id},
         version,
         plug_opts
       ) do
    parameters
    |> Enum.group_by(& &1["in"])
    |> Enum.map(fn {location, parameter_opts} ->
      case Map.fetch(@query_mappings, location) do
        {:ok, plug} ->
          quote do
            plug(
              unquote(plug),
              [__MODULE__] ++
                unquote([version, operation_id, Macro.escape(parameter_opts), plug_opts])
            )
          end

        _ ->
          raise "Unsupported parameter location: #{location}"
      end
    end)
  end

  defp parameter_plugs(_, _, _), do: []

  defp request_body_plugs(
         %{"requestBody" => %{"content" => content}, "operationId" => operation_id},
         version,
         plug_opts
       ) do
    Enum.map(content, fn {content_type, content_opts} ->
      quote do
        plug(
          Apical.Plugs.RequestBody,
          [__MODULE__] ++
            unquote([version, operation_id, content_type, Macro.escape(content_opts), plug_opts])
        )
      end
    end)
  end

  defp request_body_plugs(_, _, _), do: []

  defp validator(body, resource, pointer, fn_name, opts) do
    List.wrap(
      if Map.get(body, "schema") do
        schema_pointer =
          pointer
          |> JsonPtr.join("schema")
          |> JsonPtr.to_uri()
          |> to_string
          |> String.trim_leading("#")

        opts = Keyword.put(opts, :entrypoint, schema_pointer)

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

  @folded_opts ~w(controller styles nest_all_json)a

  defp fold_opts(opts, tags, operation_id) do
    # NB it's totally okay if this process is unoptimized since it
    # should be running at compile time.
    tags
    |> Enum.reverse()
    |> Enum.reduce(opts, &merge_opts(&2, &1, :tags))
    |> merge_opts(operation_id, :operation_ids)
  end

  defp merge_opts(opts, key, class) do
    merge_opts =
      opts
      |> Keyword.get(class, [])
      |> Enum.find_value(&if Atom.to_string(elem(&1, 0)) == key, do: elem(&1, 1))
      |> List.wrap()
      |> Keyword.take(@folded_opts)

    Keyword.merge(opts, merge_opts)
  end

  require Pegasus
  import NimbleParsec

  Pegasus.parser_from_string(
    """
    # see https://datatracker.ietf.org/doc/html/rfc6570#section-2.1

    ALPHA <- [A-Za-z]
    DIGIT <- [0-9]
    HEXDIG <- DIGIT / [A-Fa-f]
    pct_encoded <- '%' HEXDIG HEXDIG

    # see https://datatracker.ietf.org/doc/html/rfc6570#section-2.1

    literal <- (ascii_literals / ucschar / pct_encoded)+

    # expressions must be identifiers
    identifiers <- [A-Za-z_] [A-Za-z0-9_]*

    LBRACKET <- "{"
    RBRACKET <- "}"
    expression <- LBRACKET identifiers+ RBRACKET

    path <- (expression / literal)+ eof
    eof <- !.
    """,
    LBRACKET: [ignore: true],
    RBRACKET: [ignore: true],
    expression: [post_traverse: :to_colon_form],
    path: [parser: true]
  )

  defcombinatorp(:unreserved_extra, ascii_char(~C'-._~'))

  defcombinatorp(
    :ucschar,
    utf8_char([
      0xA0..0xD7FF,
      0xF900..0xFDCF,
      0xFDF0..0xFFEF,
      0x10000..0x1FFFD,
      0x20000..0x2FFFD,
      0x30000..0x3FFFD,
      0x40000..0x4FFFD,
      0x50000..0x5FFFD,
      0x60000..0x6FFFD,
      0x70000..0x7FFFD,
      0x80000..0x8FFFD,
      0x90000..0x9FFFD,
      0xA0000..0xAFFFD,
      0xB0000..0xBFFFD,
      0xC0000..0xCFFFD,
      0xD0000..0xDFFFD,
      0xE1000..0xEFFFD
    ])
  )

  defcombinatorp(
    :ascii_literals,
    ascii_char([
      0x21,
      0x23,
      0x24,
      0x26,
      0x28..0x3B,
      0x3D,
      0x3F..0x5B,
      0x5D,
      0x5F,
      0x61..0x7A,
      0x7E
    ])
  )

  defp to_colon_form(rest, var, context, _line, _offset) do
    parameter =
      var
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    {rest, var ++ ~C':', Map.update!(context, :path_parameters, &[parameter | &1])}
  end
end
