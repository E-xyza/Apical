defmodule ApicalTest.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Use the endpoint module as the endpoint
      @endpoint __MODULE__.Endpoint
      @after_compile __MODULE__

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest

      Application.put_env(:apical, @endpoint, adapter: Bandit.PhoenixAdapter)

      setup_all do
        __MODULE__.Endpoint.start_link()
        :ok
      end

      def __after_compile__(_, _) do
        module = __MODULE__
        endpoint = Module.concat(module, Endpoint)
        Code.eval_quoted(quote do
          defmodule unquote(endpoint) do
            use Phoenix.Endpoint, otp_app: :apical

            plug unquote(module)
          end
        end)
      end
    end
  end

  setup _tags do
    %{conn: Phoenix.ConnTest.build_conn()}
  end
end
