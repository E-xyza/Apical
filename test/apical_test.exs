defmodule ApicalTest do
  use ExUnit.Case
  doctest Apical

  test "greets the world" do
    assert Apical.hello() == :world
  end
end
