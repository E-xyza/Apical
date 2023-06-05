defmodule Apical.Plugs.Parameter do
  @callback name() :: atom()
  @callback default_style() :: String.t()
  @callback style_allowed?(String.t()) :: boolean
end
