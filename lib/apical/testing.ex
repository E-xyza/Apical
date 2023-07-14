defmodule Apical.Testing do
  @moduledoc false

  def set_controller(opts) do
    case Keyword.fetch(opts, :testing) do
      {:ok, :auto} ->
        Keyword.put(opts, :controller, resolve_controller(opts, []))

      {:ok, testing_opts} ->
        Keyword.put(opts, :controller, resolve_controller(opts, testing_opts))

      :error ->
        opts
    end
  end

  defp resolve_controller(opts, testing_opts) do
    default_controller =
      opts
      |> Keyword.fetch!(:router)
      |> Module.concat(Controller)

    Keyword.get(testing_opts, :controller, default_controller)
  end

  defmacro build(options) do
    router = __CALLER__.module
    operation_ids = Keyword.fetch!(options, :operation_ids)
    behaviour = Keyword.get(options, :behaviour, Module.concat(router, Api))
    controller = Keyword.get(options, :controller, Module.concat(router, Controller))
    mock = Keyword.get(options, :mock, Module.concat(router, Mock))

    behaviour_code = build_behaviour(behaviour, operation_ids)
    mock_code = build_mock(mock, behaviour)
    controller_code = build_controller(behaviour, mock, controller, operation_ids)
    bypass_code = if Keyword.get(options, :bypass, false), do: build_bypass()

    quote do
      @router unquote(router)
      @mock unquote(mock)
      unquote(behaviour_code)
      unquote(mock_code)
      unquote(controller_code)
      unquote(bypass_code)
    end
  end

  def build_tests(%{"paths" => paths}, options) do
    case Keyword.fetch(options, :testing) do
      {:ok, :auto} ->
        do_build_tests(paths, bypass: true)

      {:ok, opts} ->
        do_build_tests(paths, opts)

      :error ->
        quote do
        end
    end
  end

  defp do_build_tests(paths, opts) do
    operation_ids =
      Enum.flat_map(paths, fn {_path, verbs} ->
        Enum.map(verbs, fn {_verb, %{"operationId" => operation_id}} ->
          String.to_atom(operation_id)
        end)
      end)

    opts = Keyword.put(opts, :operation_ids, operation_ids)

    quote do
      require Apical.Testing
      Apical.Testing.build(unquote(opts))
    end
  end

  defp build_behaviour(behaviour, operation_ids) do
    quote bind_quoted: binding() do
      defmodule behaviour do
        for operation <- operation_ids do
          @callback unquote(operation)(Plug.Conn.t(), term) :: Plug.Conn.t()
        end
      end
    end
  end

  defp build_controller(behaviour, mock, controller, operation_ids) do
    quote bind_quoted: binding() do
      defmodule controller do
        @behaviour behaviour
        use Apical.Plug.Controller

        for operation <- operation_ids do
          @impl true
          defdelegate unquote(operation)(conn, params), to: mock
        end
      end
    end
  end

  defp build_mock(mock, behaviour) do
    quote do
      require Mox
      Mox.defmock(unquote(mock), for: unquote(behaviour))
    end
  end

  defp build_bypass do
    quote do
      defp respond(conn, exception) do
        status = Map.get(exception, :plug_status, 500)
        Plug.Conn.send_resp(conn, status, Exception.message(exception))
      end

      def bypass(bypass, opts \\ []) do
        this = self()

        Bypass.expect(bypass, fn conn ->
          Mox.allow(@mock, this, self())

          try do
            @router.call(conn, @router.init(opts))
          rescue
            e in Plug.Conn.WrapperError ->
              respond(conn, e.reason)

            e ->
              respond(conn, e)
          end
        end)
      end
    end
  end
end
