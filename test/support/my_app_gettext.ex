# The Gettext backend and calling module of the `ex_cldr_messages` 2.0.1
# tests (`mix/my_app_getttext.ex` and `mix/my_app_gettext_use.ex`), with
# the MF1 interpolation module in place of a `Cldr.Gettext.Interpolation`
# module.
defmodule MyApp.Gettext do
  @moduledoc false

  use Gettext.Backend,
    otp_app: :localize_mf1,
    interpolation: Localize.Message.MF1.Gettext.Interpolation,
    priv: "test/fixtures/gettext"
end

defmodule MyApp.Gettext.Use do
  @moduledoc false

  use Gettext, backend: MyApp.Gettext

  def translate_compile_time(bindings \\ nil)

  # Static bindings.
  def translate_compile_time(nil) do
    gettext("Goodbye {name}!", %{name: "José"})
  end

  # Dynamic bindings.
  def translate_compile_time(bindings) do
    gettext("Hello {name}!", bindings)
  end

  def translate_complex do
    gettext("This is your {count, number, ordinal} jab", count: 2)
  end
end
