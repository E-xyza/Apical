defmodule Apical.RemoteRefs do
  @moduledoc """
  Handles resolution of remote $ref references from a local cache.

  Remote references (URLs starting with http:// or https://) are resolved
  from a local cache directory. The URL is converted to a file path within
  the cache directory.

  For example, with cache directory `/app/cache`:
  - `https://example.com/schemas/user.json` -> `/app/cache/example.com/schemas/user.json`

  ## Usage

  Configure the cache directory via the `:remote_refs_cache` option:

      Apical.router_from_string(schema,
        remote_refs_cache: "priv/openapi_cache"
      )

  ## Populating the Cache

  The cache must be populated manually before compilation. You can use `curl` or
  a similar tool to download schemas:

      mkdir -p priv/openapi_cache/example.com/schemas
      curl -o priv/openapi_cache/example.com/schemas/user.json \\
           https://example.com/schemas/user.json
  """

  @doc """
  Resolves all remote refs in a schema, inlining them from the cache.

  Returns the schema with remote refs converted to local refs and the
  referenced content merged into the schema.
  """
  @spec resolve(map, keyword) :: map
  def resolve(schema, opts) do
    cache_dir = Keyword.get(opts, :remote_refs_cache)
    resolve_recursive(schema, cache_dir, %{}, [])
  end

  defp resolve_recursive(schema, cache_dir, loaded_refs, path) when is_map(schema) do
    case schema do
      %{"$ref" => ref} when is_binary(ref) ->
        if remote_ref?(ref) do
          resolve_remote_ref(ref, cache_dir, loaded_refs, path)
        else
          {schema, loaded_refs}
        end

      _ ->
        Enum.reduce(schema, {%{}, loaded_refs}, fn {key, value}, {acc_schema, acc_refs} ->
          {resolved_value, new_refs} =
            resolve_recursive(value, cache_dir, acc_refs, path ++ [key])

          {Map.put(acc_schema, key, resolved_value), new_refs}
        end)
    end
  end

  defp resolve_recursive(schema, cache_dir, loaded_refs, path) when is_list(schema) do
    {resolved, final_refs} =
      schema
      |> Enum.with_index()
      |> Enum.reduce({[], loaded_refs}, fn {item, index}, {acc_list, acc_refs} ->
        {resolved_item, new_refs} =
          resolve_recursive(item, cache_dir, acc_refs, path ++ [index])

        {[resolved_item | acc_list], new_refs}
      end)

    {Enum.reverse(resolved), final_refs}
  end

  defp resolve_recursive(value, _cache_dir, loaded_refs, _path), do: {value, loaded_refs}

  defp remote_ref?(ref) do
    String.starts_with?(ref, "http://") or String.starts_with?(ref, "https://")
  end

  defp resolve_remote_ref(ref, nil, _loaded_refs, path) do
    raise CompileError,
      description: """
      Remote ref encountered but no cache configured.

      Found remote $ref: #{ref}
      At path: #{inspect(path)}

      To use remote refs, configure the cache directory:

          Apical.router_from_string(schema,
            remote_refs_cache: "priv/openapi_cache"
          )

      Then populate the cache with the remote schemas.
      """
  end

  defp resolve_remote_ref(ref, cache_dir, loaded_refs, path) do
    {url, fragment} = split_ref(ref)
    cache_path = url_to_cache_path(url, cache_dir)

    # Check if we've already loaded this URL
    {content, loaded_refs} =
      case Map.fetch(loaded_refs, url) do
        {:ok, content} ->
          {content, loaded_refs}

        :error ->
          content = load_from_cache(url, cache_path, path)
          {content, Map.put(loaded_refs, url, content)}
      end

    # Resolve the fragment within the loaded content
    resolved =
      if fragment do
        pointer = JsonPtr.from_uri("#" <> fragment)

        case JsonPtr.resolve_json(content, pointer) do
          {:ok, value} -> value
          :error -> raise_fragment_error(ref, fragment, cache_path, path)
        end
      else
        content
      end

    # Inline the resolved content directly (no $ref)
    {resolved, loaded_refs}
  end

  defp split_ref(ref) do
    case String.split(ref, "#", parts: 2) do
      [url, fragment] -> {url, fragment}
      [url] -> {url, nil}
    end
  end

  defp url_to_cache_path(url, cache_dir) do
    uri = URI.parse(url)
    # Remove scheme (http:// or https://)
    # Path becomes: cache_dir/host/path
    path_parts = [uri.host | Path.split(uri.path || "/")]
    Path.join([cache_dir | path_parts])
  end

  defp load_from_cache(url, cache_path, path) do
    case File.read(cache_path) do
      {:ok, content} ->
        parse_content(content, cache_path)

      {:error, :enoent} ->
        raise CompileError,
          description: """
          Remote ref not found in cache.

          URL: #{url}
          Expected cache path: #{cache_path}
          At schema path: #{inspect(path)}

          To fix, download the schema to the cache:

              mkdir -p #{Path.dirname(cache_path)}
              curl -o #{cache_path} #{url}
          """

      {:error, reason} ->
        raise CompileError,
          description: """
          Failed to read cached remote ref.

          URL: #{url}
          Cache path: #{cache_path}
          Error: #{inspect(reason)}
          """
    end
  end

  defp parse_content(content, path) do
    cond do
      String.ends_with?(path, ".json") ->
        Jason.decode!(content)

      String.ends_with?(path, ".yaml") or String.ends_with?(path, ".yml") ->
        YamlElixir.read_from_string!(content)

      true ->
        # Try JSON first, then YAML
        case Jason.decode(content) do
          {:ok, parsed} -> parsed
          {:error, _} -> YamlElixir.read_from_string!(content)
        end
    end
  end

  defp raise_fragment_error(ref, fragment, cache_path, path) do
    raise CompileError,
      description: """
      Could not resolve fragment in remote ref.

      Ref: #{ref}
      Fragment: ##{fragment}
      Cache path: #{cache_path}
      At schema path: #{inspect(path)}

      The fragment pointer does not exist in the cached document.
      """
  end
end
