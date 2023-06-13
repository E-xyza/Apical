defmodule Apical.Plugs.Parameter do
  @callback name() :: atom()
  @callback default_style() :: String.t()
  @callback style_allowed?(String.t()) :: boolean

  def validator_name(version, operation_id, name) do
    :"#{version}-#{operation_id}-#{name}"
  end
end
