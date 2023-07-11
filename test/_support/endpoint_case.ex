defmodule ApicalTest.EndpointCase do
  use ExUnit.CaseTemplate

  using opts do
    opts
    |> Keyword.get(:with, Phoenix)
    |> Macro.expand(__ENV__)
    |> dbg(limit: 25)
    |> case do
      Plug ->
        port = Enum.random(2000..3000)
        plug_endpoint(port)
      Phoenix ->
        phoenix_endpoint()
    end
  end

  defp plug_endpoint(port) do
    quote do
      @port unquote(port)

      setup_all do
        start_supervised({Bandit, plug: __MODULE__.Router, port: @port})
        :ok
      end
    end
  end

  defp phoenix_endpoint do
    quote do
      # Use the endpoint module as the endpoint
      @endpoint __MODULE__.Endpoint
      @after_compile __MODULE__
      use Phoenix.Controller

      # Import conveniences for testing with connections
      import Phoenix.ConnTest

      Application.put_env(:apical, @endpoint, adapter: Bandit.PhoenixAdapter)

      setup_all do
        __MODULE__.Endpoint.start_link()
        :ok
      end

      def __after_compile__(_, _) do
        router = Module.concat(__MODULE__, Router)
        endpoint = Module.concat(__MODULE__, Endpoint)

        Code.eval_quoted(
          quote do
            defmodule unquote(endpoint) do
              use Phoenix.Endpoint, otp_app: :apical

              plug(unquote(router))
            end
          end
        )
      end
    end
  end

  setup _tags do
    %{conn: Phoenix.ConnTest.build_conn()}
  end
end
