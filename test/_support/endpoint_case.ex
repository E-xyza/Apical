defmodule ApicalTest.EndpointCase do
  use ExUnit.CaseTemplate

  @doc """
  Macro to define the endpoint module. Must be called after the Router is defined.
  """
  defmacro define_endpoint do
    quote do
      defmodule Endpoint do
        use Phoenix.Endpoint, otp_app: :apical

        plug(unquote(__CALLER__.module).Router)
      end
    end
  end

  using opts do
    opts
    |> Keyword.get(:with, Phoenix)
    |> Macro.expand(__ENV__)
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
      use Phoenix.Controller

      # Import conveniences for testing with connections
      import Phoenix.ConnTest

      setup_all do
        Application.put_env(:apical, @endpoint, adapter: Bandit.PhoenixAdapter)
        __MODULE__.Endpoint.start_link()
        :ok
      end
    end
  end

  setup _tags do
    %{conn: Phoenix.ConnTest.build_conn()}
  end
end
