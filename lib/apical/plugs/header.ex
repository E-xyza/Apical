defmodule Apical.Plugs.Header do
  @behaviour Plug
  @behaviour Apical.Plugs.Parameter

  alias Apical.Plugs.Common

  @impl Plug
  def init(opts) do
    Common.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations) do
    headers = MapSet.new(conn.req_headers, &elem(&1, 0))

    operations
    |> Map.get(:required, [])
    |> Enum.each(fn required_header ->
      unless required_header in headers do
        raise Apical.Exceptions.ParameterError,
          operation_id: conn.private.operation_id,
          in: :header,
          reason: "required header `#{required_header}` not present"
      end
    end)

    params = Apical.Conn.fetch_header_params!(conn, operations.parser_context)

    conn
    |> Map.update!(:params, &Map.merge(&1, params))
    |> Common.warn_deprecated(params, :header, operations)
    |> Common.validate(params, :header, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :header

  @impl Apical.Plugs.Parameter
  def default_style, do: "simple"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style === "simple"
end
