defmodule Apical.Paths do
  # see: https://datatracker.ietf.org/doc/html/rfc6570#section-3.2.3
  #   to understand path expansion rules.

  alias Apical.Plugs.Parameter
  alias Apical.Plugs.RequestBody
  alias Apical.Tools
  alias Apical.Validators

  def to_routes(_pointer, path, %{"$ref" => ref}, schema, opts) do
    # for now, don't handle the remote ref scenario, or the id scenario.
    new_pointer = JsonPtr.from_uri(ref)
    subschema = JsonPtr.resolve_json!(schema, new_pointer)
    to_routes(new_pointer, path, subschema, schema, opts)
  end

  def to_routes(pointer, path, _subschema, schema, opts) do
    # each route contains a map of verbs to operations.
    # map over that content to generate routes.
    JsonPtr.map(pointer, schema, &to_route(&1, &2, &3, schema, path, opts))
  end

  @verb_mapping Map.new(~w(get put post delete options head patch trace)a, &{"#{&1}", &1})
  @verbs Map.keys(@verb_mapping)

  defp to_route(pointer, verb, operation, schema, path, opts) when verb in @verbs do
    Tools.assert(
      Map.has_key?(operation, "operationId"),
      "that all operations have an operationId: (missing for operation at `#{JsonPtr.to_path(pointer)}`)"
    )

    operation_id = Map.fetch!(operation, "operationId")

    {canonical_path, path_parameters} =
      case parse_path(path, context: %{path_parameters: []}) do
        {:ok, canonical, "", context, _, _} ->
          {"#{canonical}", context.path_parameters}

        _ ->
          raise CompileError, description: "path #{path} is not a valid path template"
      end

    verb = Map.fetch!(@verb_mapping, verb)

    tags = Map.get(operation, "tags", [])
    opts = fold_opts(opts, tags, operation_id)
    version = Keyword.fetch!(opts, :version)
    root = Keyword.fetch!(opts, :root)

    operation_pipeline = :"#{version}-#{operation_id}"
    # TODO: resolve function using operationId options
    function = String.to_atom(operation_id)

    plug_opts =
      opts
      |> Keyword.take(
        ~w(styles parameters nest_all_json content_sources version resource dump dump_validator)a
      )
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

    extra_plugs =
      opts
      |> Keyword.get(:extra_plugs, [])
      |> Enum.map(fn
        {plug, plug_opts} ->
          quote do
            plug(unquote(plug), unquote(plug_opts))
          end

        plug ->
          quote do
            plug(unquote(plug))
          end
      end)

    {parameter_plugs, parameter_validators} =
      Parameter.make(pointer, schema, operation_id, plug_opts)

    {body_plugs, body_validators} = RequestBody.make(pointer, schema, operation_id, plug_opts)

    quote do
      # TODO: make these functions
      unquote(parameter_validators)
      unquote(body_validators)

      pipeline unquote(operation_pipeline) do
        unquote(extra_plugs)

        plug(Apical.Plugs.SetVersion, unquote(version))
        plug(Apical.Plugs.SetOperationId, unquote(operation_id))
        unquote(parameter_plugs)

        unquote(body_plugs)
      end

      scope unquote(root) do
        pipe_through(unquote(operation_pipeline))
        unquote(verb)(unquote(canonical_path), unquote(controller), unquote(function))
      end
    end
  end

  @folded_opts ~w(controller styles parameters extra_plugs nest_all_json content_sources dump dump_validator)a

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

    Tools.deepmerge(opts, merge_opts)
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

    parse_path <- (expression / literal)+ eof
    eof <- !.
    """,
    LBRACKET: [ignore: true],
    RBRACKET: [ignore: true],
    expression: [post_traverse: :to_colon_form],
    parse_path: [parser: true]
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
