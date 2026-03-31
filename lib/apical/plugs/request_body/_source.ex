defmodule Apical.Plugs.RequestBody.Source do
  @moduledoc """
  Behaviour for adapters that process request bodies and alter the conn.
  """

  alias Plug.Conn

  @typedoc """
  Type for a function that encapsulates the logic for validating a request body.

  The function should return `:ok` if the body is valid, or `{:error, keyword}`

  In the generic case, keyword should contain the key `:message` which determines
  what the request body error message will be.

  For more specific cases, see the documentation for `Exonerate` which describes
  the fields available.

  The default validator (if no validation is to be performed) will return `:ok`
  on any input.
  """
  @type validator :: nil | {module, atom} | {module, atom, keyword}

  @typedoc """
  Type for marshal context that contains type information for marshalling
  request body values from strings to their proper types.
  """
  @type marshal_context :: map | nil

  @doc """
  Fetches and processes the request body.

  The marshal_context parameter contains type information extracted from the schema
  that can be used to convert string values to their proper types (e.g., "42" to 42).
  """
  @callback fetch(Conn.t(), validator, marshal_context, opts :: keyword) ::
              {:ok, Conn.t()} | {:error, keyword}

  @doc """
  Compile-time check to see if the validator is valid for the given requestBody
  subschema.

  This may reject for any reason and should raise a CompileError if the validator
  cannot be used for that subschema.
  """
  @callback validate!(subschema :: map, operation_id :: String.t()) :: :ok

  @spec fetch_body(Conn.t(), keyword) :: {:ok, body :: iodata, Conn.t()} | {:error, any}
  @doc """
  Utility function that grabs request bodies.

  `Apical.Plugs.RequestBody.Source` modules are expected to use this function
  if they need the request body, since it conforms to the options keyword that
  plug uses natively.  This function will exhaust the ability of the `conn` to
  have its body fetched.  Thus, the use of this function is *not* required

  > ### Streaming request bodies {: .warning }
  >
  > If the request body source plugin processes data in a streaming fashion, this
  > function should not be used, instead manually call `Plug.Conn.read_body/2`
  > in your plugin's `c:fetch/3` function

  ### options

  `:length` (integer, default `8_000_000`) - total maximum length of the request body.
  `:read_length` (integer, default `1_000_000`) - maximum length of each chunk.
  `:string` (boolean, default `false`) - if true, the result will be a single binary,
    if false, the result *may* be an improper iolist.
  """
  def fetch_body(conn, opts) do
    content_length = conn.private.content_length
    max_length = Keyword.get(opts, :length, 8_000_000)
    string? = Keyword.get(opts, :string, true)
    chunk_opts = [length: Keyword.get(opts, :read_length, 1_000_000)]

    case content_length do
      :chunked ->
        # For chunked encoding, read until done with max_length safety limit
        fetch_body_chunked(conn, [], 0, max_length, string?, chunk_opts)

      content_length when is_integer(content_length) ->
        if content_length > max_length do
          raise Apical.Exceptions.RequestBodyTooLargeError,
            max_length: max_length,
            content_length: content_length
        end

        fetch_body_fixed(conn, [], content_length, string?, chunk_opts)
    end
  end

  # Fixed content-length body reading
  defp fetch_body_fixed(conn, so_far, length, string?, chunk_opts) do
    case Conn.read_body(conn, chunk_opts) do
      {:ok, last, conn} when :erlang.byte_size(last) == length ->
        full_iodata = [so_far | last]

        if string? do
          {:ok, IO.iodata_to_binary(full_iodata), conn}
        else
          {:ok, full_iodata, conn}
        end

      {:ok, _, _} ->
        {:error, :body_length}

      {:more, chunk, conn} ->
        new_size = length - :erlang.byte_size(chunk)
        fetch_body_fixed(conn, [so_far | chunk], new_size, string?, chunk_opts)

      error = {:error, _} ->
        error
    end
  end

  # Chunked transfer-encoding body reading
  defp fetch_body_chunked(conn, so_far, bytes_read, max_length, string?, chunk_opts) do
    case Conn.read_body(conn, chunk_opts) do
      {:ok, last, conn} ->
        total_bytes = bytes_read + byte_size(last)

        if total_bytes > max_length do
          raise Apical.Exceptions.RequestBodyTooLargeError,
            max_length: max_length,
            content_length: total_bytes
        end

        full_iodata = [so_far | last]

        if string? do
          {:ok, IO.iodata_to_binary(full_iodata), conn}
        else
          {:ok, full_iodata, conn}
        end

      {:more, chunk, conn} ->
        new_bytes_read = bytes_read + byte_size(chunk)

        if new_bytes_read > max_length do
          raise Apical.Exceptions.RequestBodyTooLargeError,
            max_length: max_length,
            content_length: new_bytes_read
        end

        fetch_body_chunked(
          conn,
          [so_far | chunk],
          new_bytes_read,
          max_length,
          string?,
          chunk_opts
        )

      error = {:error, _} ->
        error
    end
  end

  @doc false
  # private utility function to consistently apply validators to request body
  # fetch results.
  def apply_validator(_content, nil), do: :ok

  def apply_validator(content, {module, fun}) do
    apply(module, fun, [content])
  end

  def apply_validator(content, {module, fun, args}) do
    apply(module, fun, [content | args])
  end

  alias Apical.Parser.Marshal

  @doc false
  # Apply marshalling to convert string values to proper types based on schema
  def apply_marshal(content, nil), do: {:ok, content}

  def apply_marshal(content, marshal_context) when is_map(content) do
    Marshal.marshal(content, marshal_context, marshal_context[:type])
  end

  def apply_marshal(content, marshal_context) when is_list(content) do
    Marshal.marshal(content, marshal_context, marshal_context[:type])
  end

  def apply_marshal(content, marshal_context) when is_binary(content) do
    # For primitive types, use as_type directly
    {:ok, Marshal.as_type(content, marshal_context[:type] || [:string])}
  end

  def apply_marshal(content, _), do: {:ok, content}
end
