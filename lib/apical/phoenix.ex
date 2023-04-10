defmodule Apical.Phoenix do
  def router(_openapi, opts) do
    controller = opts[:controller]

    quote do
      get("/", unquote(controller), :testGet)
    end
  end
end
