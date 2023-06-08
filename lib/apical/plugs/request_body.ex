defmodule Apical.Plugs.RequestBody do
  @behaviour Plug

  alias Apical.Plugs.Common
  alias Plug.Conn

  @impl Plug
  def init([module, operation_id, mimetype, parameters, _plug_opts]) do
    %{}
    |> add_validation(module, operation_id, mimetype, parameters)
  end

  @impl Plug
  def call(conn, operations) do
    operations |> dbg(limit: 25)
    mimetype = "application/json"

    with {:ok, body, conn} <- Conn.read_body(conn),
         # NB: this code will change
         body_params = Jason.decode!(body) do
      conn
      |> validate(body_params, mimetype, operations)
      |> Map.replace!(:body_params, body_params)
      |> Map.update!(:params, &update_params(&1, body_params, false))
    else
      {:error, _} -> raise "fatal error"
    end
  end

  @falsy [false, nil]

  defp update_params(params, body_params, nested) when is_map(body_params) and not nested do
    # we merge params into body_params so that malicious payloads can't overwrite the cleared
    # type checking performed by the params parsing.
    Map.merge(body_params, params)
  end

  defp update_params(params, body_params, _) do
    # non-object JSON content is put into a "_json" field, this matches the functionality found
    # in Plug.Parsers.JSON
    #
    # objects can also be forced into "_json" by setting :nest_all_json
    #
    # see: https://hexdocs.pm/plug/Plug.Parsers.JSON.html#module-options
    Map.put(params, "_json", body_params)
  end

  defp add_validation(operations, module, operation_id, mimetype, %{"schema" => _schema}) do
    fun = {module, :"body-#{operation_id}-#{mimetype}"}

    Map.update(operations, :validations, %{mimetype => fun}, &Map.put(&1, mimetype, fun))
  end

  defp validate(conn, body_params, mimetype, %{validations: validations})
       when is_map_key(validations, mimetype) do
    {module, fun} = Map.fetch!(validations, mimetype)

    case apply(module, fun, body_params) do
      :ok ->
        conn

      {:error, reasons} ->
        raise Apical.Exceptions.ParameterError,
              [operation_id: conn.private.operation_id, in: :body] ++ reasons
    end
  end

  defp validate(conn, _, _, _), do: conn
end
