defmodule ApicalTest.Egress.CompileEnvTest do
  use ExUnit.Case, async: true

  # Egress validation is gated on a `compile_env` flag, so what it does when the
  # flag is FALSE cannot be tested by toggling it at runtime -- the guards have
  # already been resolved.  What is testable here is that the gate is wired to
  # the flag at all, and that the suite's own setting is the one in play.

  @egress_testing Application.compile_env(:apical, :egress_testing, false)

  test "the test suite runs with egress testing enabled" do
    assert @egress_testing,
           "egress tests require `config :apical, egress_testing: true` in the test env"
  end

  test "the egress modules exist exactly when the flag is set" do
    assert Code.ensure_loaded?(Apical.Plugs.Egress) == @egress_testing
    assert Code.ensure_loaded?(Apical.Exceptions.EgressError) == @egress_testing
  end

  test "the egress error reports a 500" do
    # a 4xx would tell the client their request was rejected, which is untrue by
    # the time a response is validated: the operation has already run and any
    # side effects it had have already happened.
    error = %Apical.Exceptions.EgressError{
      operation_id: "someOperation",
      status: 200,
      media_type: "application/json",
      reason: "test"
    }

    assert error.plug_status == 500
    assert Plug.Exception.status(error) == 500
  end
end
