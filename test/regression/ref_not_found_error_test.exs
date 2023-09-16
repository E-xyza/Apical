defmodule ApicalTest.Regression.RefNotFoundErrorTest do
  use ExUnit.Case, async: true
  use Phoenix.Router

  require Apical

  Apical.router_from_string(
    """
    openapi: 3.1.0
    info:
      title: This API Fails
      version: '1.0'
    paths:
      "/foo":
        post:
          operationId: foo
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/Root'
    components:
      schemas:
        Root:
          type: object
          properties:
            abc:
              $ref: '#/components/schemas/Leaf'
        Leaf:
          type: string
    """,
    encoding: "application/yaml",
    controller: __MODULE__
  )

  def init(_), do: raise "not called"

  # this schema used to trigger a compilation error
  test "works", do: :ok
end
