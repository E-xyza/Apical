defmodule ApicalTest.TestTest do
  # tests using Apical in "test" mode where it creates a bypass server.

  use ExUnit.Case, async: true

  alias ApicalTest.TestTest.Router
  alias ApicalTest.TestTest.Mock

  setup do
    bypass = Bypass.open()
    Router.bypass(bypass)
    {:ok, bypass: bypass}
  end

  test "content can be served", %{bypass: bypass} do
    Mox.expect(Mock, :testGet, fn conn, _params ->
      Plug.Conn.send_resp(conn, 200, "OK")
    end)

    assert %{status: 200} = Req.get!("http://localhost:#{bypass.port}/?foo=bar")
  end

  test "content can be rejected", %{bypass: bypass} do
    # this one should never reach because it's filtered out as a 400 before it gets
    # to the controller.

    assert %{status: 400} = Req.get!("http://localhost:#{bypass.port}/?foo=baz")
  end
end
