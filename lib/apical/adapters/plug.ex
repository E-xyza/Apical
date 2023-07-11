defmodule Apical.Adapters.Plug do

  @methods Map.new(~w(get post put patch delete head options trace)a, &{&1, String.upcase(to_string(&1))})

  @moduledoc false
  def build_path(path) do
    # to get proper plug segregation, we have to create a module for each
    # operation.  In order to name these plugs, we'll use a hash of the
    # version and the operation id.

    module_name =
      :sha256 |> :crypto.hash("#{path.version}-#{path.operation_id}") |> Base.encode16()

    module_alias = {:__aliases__, [alias: false], [String.to_atom(module_name)]}

    match_parts =
      path.root
      |> Path.join(path.canonical_path)
      |> String.split("/")
      |> Enum.map(&split_on_matches/1)
      |> Enum.reject(&(&1 == ""))
      |> Macro.escape()

    method = Map.fetch!(@methods, path.verb)

    quote do
      previous = Module.get_attribute(__MODULE__, :operations, [])

      Module.put_attribute(__MODULE__, :operations, [
        {:operation, unquote(module_alias)} | previous
      ])

      defmodule unquote(module_alias) do
        use Plug.Builder

        unquote(path.parameter_validators)
        unquote(path.body_validators)

        unquote(path.extra_plugs)

        plug(Apical.Plugs.SetVersion, unquote(path.version))
        plug(Apical.Plugs.SetOperationId, unquote(path.operation_id))
        unquote(path.parameter_plugs)

        unquote(path.body_plugs)

        plug(unquote(path.controller), unquote(path.function))

        @impl Plug
        def init(_), do: []

        @impl Plug
        def call(conn = %{method: unquote(method)}, opts) do
          if matched_conn = Apical.Adapters.Plug._path_match(conn, unquote(match_parts)) do
            super(matched_conn, opts)
          else
            conn
          end
        end

        def call(conn, _opts), do: conn
      end
    end
  end

  def _path_match(conn, match_parts) do
    find_match(conn, conn.path_info, match_parts)
  end

  defp split_on_matches(string) do
    case String.split(string, ":") do
      [no_colon] ->
        no_colon

      [_, ""] ->
        raise "invalid path: `#{string}`"

      [match_str, key] ->
        {match_str, key, byte_size(match_str)}

      _ ->
        raise "invalid path: `#{string}`"
    end
  end

  defp find_match(conn, [], []), do: conn

  defp find_match(conn, [path_part | path_rest], [path_part | match_rest]) do
    find_match(conn, path_rest, match_rest)
  end

  defp find_match(conn, [path_part | path_rest], [{"", match_var, _} | match_rest]) do
    # optimization of next clause
    conn
    |> put_path_param(match_var, path_part)
    |> find_match(path_rest, match_rest)
  end

  defp find_match(conn, [path_part | path_rest], [{match_str, key, match_len} | match_rest]) do
    case :binary.part(path_part, 0, match_len) do
      ^match_str ->
        value = :binary.part(path_part, match_len, byte_size(path_part) - match_len)

        conn
        |> put_path_param(key, value)
        |> find_match(path_rest, match_rest)

      _ ->
        nil
    end
  end

  defp find_match(_, _, _), do: nil

  defp put_path_param(conn = %{params: %Plug.Conn.Unfetched{}}, key, value) do
    %{conn | params: %{key => value}}
  end

  defp put_path_param(conn = %{params: params}, key, value) do
    %{conn | params: Map.put(params, key, value)}
  end
end
