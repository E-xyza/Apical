import Config

# Egress (response) schema validation is compiled in only when this is true.
# It is read with `Application.compile_env/3`, so toggling it requires a
# recompile of `:apical` and anything that generated a router.
#
# Generally this belongs in `config/test.exs` of the *consuming* application:
# validating responses costs a schema check on every request and raises a 500
# when a response does not match the schema, which is what you want in a test
# suite and usually not what you want in production.
config :apical, egress_testing: config_env() == :test
