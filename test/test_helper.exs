Logger.configure(level: :info)

:application.ensure_all_started(:bypass)
:application.ensure_all_started(:mox)

ExUnit.start()
