defmodule Apical.Paths do
  # see: https://datatracker.ietf.org/doc/html/rfc6570#section-3.2.3
  #   to understand path expansion rules.

  def to_routes({path, methods}, opts) do
    base_pointer =
      "/paths"
      |> JsonPointer.from_path()
      |> JsonPointer.join(path)

    Enum.map(methods, &to_route(path, &1, base_pointer, opts))
  end

  @verb_mapping Map.new(~w(get put post delete options head patch trace)a, &{"#{&1}", &1})
  @verbs Map.keys(@verb_mapping)

  defp to_route(path, {verb, operation = %{"operationId" => operation_id}}, base_pointer, opts)
       when verb in @verbs do
    # TODO: check all path substitutions have corresponding parameters.
    canonical_path =
      case path(path) do
        {:ok, canonical, "", _, _, _} ->
          "#{canonical}"

        _ ->
          raise CompileError, description: "path #{path} is not a valid path template"
      end

    verb_pointer = JsonPointer.join(base_pointer, verb)
    verb = Map.fetch!(@verb_mapping, verb)
    # TODO: resolve controller using controller options
    controller = opts[:controller]
    operation_pipeline = String.to_atom(operation_id)
    # TODO: resolve function using operationId options
    function = String.to_atom(operation_id)

    plug_opts = Keyword.take(opts, [:styles])

    # generate exonerate validators.
    parameter_validators =
      operation
      |> Map.get("parameters")
      |> List.wrap()
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {subschema, index} ->
          pointer = JsonPointer.join(verb_pointer, ["parameters", "#{index}"])
          validators(subschema, Keyword.fetch!(opts, :name), pointer, operation_id, opts)
      end)

    body_validators =
      operation
      |> get_in(~w(requestBody content))
      |> Kernel.||([])
      |> dbg(limit: 25)
      |> Enum.flat_map(fn
        {mimetype, subschema} ->
          pointer = JsonPointer.join(verb_pointer, ["requestBody", "content", mimetype])
          body_validator(subschema, Keyword.fetch!(opts, :name), mimetype, pointer, operation_id, opts)
      end)

    quote do
      unquote(parameter_validators)
      unquote(body_validators)

      pipeline unquote(operation_pipeline) do
        plug(Apical.Plugs.SetOperationId, unquote(operation_pipeline))
        unquote(parameter_plugs(operation, plug_opts))
        unquote(request_body_plugs(operation, plug_opts))
      end

      scope unquote(canonical_path) do
        pipe_through(unquote(operation_pipeline))
        unquote(verb)("/", unquote(controller), unquote(function))
      end
    end
  end

  @query_mappings %{
    "query" => Apical.Plugs.Query,
    "header" => Apical.Plugs.Header,
    "path" => Apical.Plugs.Path,
    "cookie" => Apical.Plugs.Cookie
  }

  defp parameter_plugs(%{"parameters" => parameters, "operationId" => operation_id}, plug_opts) do
    parameters
    |> Enum.group_by(& &1["in"])
    |> Enum.map(fn {location, parameter_opts} ->
      case Map.fetch(@query_mappings, location) do
        {:ok, plug} ->
          quote do
            plug(
              unquote(plug),
              [__MODULE__] ++ unquote([operation_id, Macro.escape(parameter_opts), plug_opts])
            )
          end

        _ ->
          raise "Unsupported parameter location: #{location}"
      end
    end)
  end

  defp parameter_plugs(_, _), do: []

  defp request_body_plugs(
         %{"requestBody" => %{"content" => content}, "operationId" => operation_id},
         plug_opts
       ) do
    Enum.map(content, fn {content_type, content_opts} ->
      quote do
        plug(
          Apical.Plugs.RequestBody,
          [__MODULE__] ++
            unquote([operation_id, content_type, Macro.escape(content_opts), plug_opts])
        )
      end
    end)
  end

  defp request_body_plugs(_, _), do: []

  defp validators(parameter = %{"name" => name}, resource, pointer, operation_id, opts) do
    fn_name = :"#{operation_id}-#{name}"

    List.wrap(
      if Map.get(parameter, "schema") do
        schema_pointer =
          pointer
          |> JsonPointer.join("schema")
          |> JsonPointer.to_uri()
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

  defp body_validator(body, resource, mimetype, pointer, operation_id, opts) do
    fn_name = :"body-#{operation_id}-#{mimetype}"
    body |> dbg(limit: 25)
    fn_name |> dbg(limit: 25)

    List.wrap(
      if Map.get(body, "schema") do
        schema_pointer =
          pointer
          |> JsonPointer.join("schema")
          |> JsonPointer.to_uri()
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
    {rest, var ++ ~C':', context}
  end
end
