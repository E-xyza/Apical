defmodule ApicalTest.Plug.DigitHashAliasTest do
  # Regression: the Plug adapter names each operation's plug module from the hex
  # SHA256 of "version-operationId". A hex digest can start with a digit, which is
  # not a valid alias segment (aliases must begin uppercase), so those operations
  # raised `:as, expected an alias` at compile time. `operationId: createItem` at
  # version 1.0.0 hashes to a digit-leading digest, so this router only compiles
  # if the adapter prefixes the hash to form a valid alias.
  use ApicalTest.EndpointCase, with: Plug
  alias Plug.Conn

  use Apical.Plug.Controller

  def createItem(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "an operation whose hash starts with a digit compiles and routes" do
    assert %{status: 200, body: "OK"} = Req.get!("http://localhost:#{@port}/")
  end
end

defmodule ApicalTest.Plug.DigitHashAliasTest.Router do
  use Apical.Plug.Router

  require Apical

  Apical.router_from_string(
    """
    openapi: 3.1.0
    info:
      title: DigitHashAlias
      version: 1.0.0
    paths:
      "/":
        get:
          operationId: createItem
          responses:
            "200":
              description: OK
    """,
    for: Plug,
    root: "/",
    controller: ApicalTest.Plug.DigitHashAliasTest,
    content_type: "application/yaml"
  )
end
