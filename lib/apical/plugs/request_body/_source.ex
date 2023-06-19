defmodule Apical.Plugs.RequestBody.Source do
  @moduledoc """
  Behaviour for adapters that process request bodies and alter the conn.
  """

  alias Plug.Conn
  @callback fetch(Conn.t(), opts :: keyword) :: {:ok, Conn.t} | {:ok, Conn.t, map()} | {:error, keyword}

  @spec fetch_body(Conn.t(), keyword) :: {:ok, body :: iodata, Conn.t} | {:error, any}
  @doc """
  Utility function that grabs request bodies.

  `Source` modules are expected to use this function if they need the request
  body, since it conforms to the options keyword that plug uses natively.
  However, this is not required.  If the request body needs to process data
  in a streaming fashion, this function should not be used.

  ### options
  
  `:length` (integer, default `8_000_000`) - total maximum length of the request body.
  `:read_length` (integer, default `1_000_000`) - maximum length of each chunk.
  `:string` (boolean, default `false`) - if true, the result will be a single binary,
    if false, the result *may* be an improper iolist.
  """
  def fetch_body(conn, opts) do
    with [length_str] <- Conn.get_req_header(conn, "content-length"),
         max_length = Keyword.get(opts, :length, 8_000_000),
         {{length, ""}, _length_str} when length <= max_length <-
           {Integer.parse(length_str), length_str} do
      chunk_opts = [length: Keyword.get(opts, :read_length, 1_000_000)]
      string? = Keyword.get(opts, :string, true)
      fetch_body(conn, [], length, string?, chunk_opts)
    else
      # TODO: check all of these, and handle with error instead.
      [] -> raise "no content-length header found"
      {:error, _length_str} -> raise "not a length string"
      {{_, _extra}, _length_str} -> raise "not a length string"
    end
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
end
