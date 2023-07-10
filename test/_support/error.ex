defmodule ApicalTest.Support.Error do
  # before version 1.15.0 the error messages as found by assert_raise strings
  # contain a space.  This ensures passing on 1.15.0 and above.

  changeover = Version.parse!("1.15.0")

  version_compare = System.version()
  |> Version.parse!()
  |> Version.compare(changeover)

  if version_compare == :lt do
    def error_message(string) do
      " " <> string
    end
  else
    def error_message(string), do: string
  end
end
