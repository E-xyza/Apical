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

  @doc """
  """
  @callback fetch(Conn.t(), validator, opts :: keyword) :: {:ok, Conn.t()} | {:error, keyword}

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

    if content_length > max_length do
      raise Apical.Exceptions.RequestBodyTooLargeError,
        max_length: max_length,
        content_length: content_length
    end

    chunk_opts = [length: Keyword.get(opts, :read_length, 1_000_000)]
    fetch_body(conn, [], content_length, string?, chunk_opts)
  end

  defp fetch_body(conn, so_far, length, string?, chunk_opts) do
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
        fetch_body(conn, [so_far | chunk], new_size, string?, chunk_opts)

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
end
