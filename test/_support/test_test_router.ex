defmodule ApicalTest.TestTest.Router do
  use Phoenix.Router

  require Apical

  Apical.router_from_string(
    """
    openapi: 3.1.0
    info:
      title: TestGet
      version: 1.0.0
    paths:
      "/":
        get:
          operationId: testGet
          parameters:
            - in: query
              name: foo
              schema:
                type: string
                enum:
                  - bar
          responses:
            "200":
              description: OK
    """,
    root: "/",
    encoding: "application/yaml",
    testing: [
      behaviour: ApicalTest.TestTest.Api,
      controller: ApicalTest.TestTest.Controller,
      mock: ApicalTest.TestTest.Mock,
      bypass: true
    ]
  )
end
