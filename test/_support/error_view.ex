defmodule ApicalTest.ErrorView do
  def render(_, assigns) do
    "error #{assigns.status}"
  end
end
