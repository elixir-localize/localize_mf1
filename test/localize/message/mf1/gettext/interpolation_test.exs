defmodule Localize.Message.MF1.Gettext.InterpolationTest do
  # The tests of `ex_cldr_messages` 2.0.1 `test/gettext_interpolation_test.exs`,
  # ported with their expected results. The locale is Localize's rather than
  # an ex_cldr backend's, and date and time results carry CLDR's narrow
  # no-break space before AM and PM.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias MyApp.Gettext.Use

  setup do
    previous = Localize.get_locale()
    on_exit(fn -> Localize.put_locale(previous) end)
  end

  test "interpolates compile time translation" do
    assert "Hello World!" == Use.translate_compile_time(name: "World")

    assert capture_log(fn ->
             Use.translate_compile_time(%{})
           end) =~ "missing Gettext bindings: [\"name\"]"
  end

  test "interpolates runtime translation" do
    use Gettext, backend: MyApp.Gettext

    assert "runtime MXP 1.00" ==
             gettext("runtime {one, number, currency}", %{one: {1, currency: :MXP}})

    assert capture_log(fn ->
             assert "runtime {one, number, currency} two" ==
                      gettext("runtime {one, number, currency} {two}", %{two: "two"})
           end) =~ "missing Gettext bindings: [\"one\"]"
  end

  test "interpolates runtime translation with backend that has no message formats configured" do
    use Gettext, backend: MyApp.Gettext

    assert "runtime MXP 1.00" ==
             gettext("runtime {one, number, currency}", %{one: {1, currency: :MXP}})

    assert capture_log(fn ->
             assert "runtime {one, number, currency}" ==
                      gettext("runtime {one, number, currency}", %{})
           end) =~ "missing Gettext bindings: [\"one\"]"
  end

  test "interpolation with sigil_m" do
    use Gettext, backend: MyApp.Gettext
    import Localize.Message.MF1.Sigils

    assert gettext(~m"runtime {one, number, currency}", %{one: {1, currency: :MXP}}) ==
             gettext(~m"runtime {one,   number,   currency}", %{one: {1, currency: :MXP}})

    assert capture_log(fn ->
             assert "runtime {one, number, currency} two" ==
                      gettext(~m"runtime {one, number, currency} {two}", %{two: "two"})
           end) =~ "missing Gettext bindings: [\"one\"]"
  end

  test "number formatting in gettext" do
    use Gettext, backend: MyApp.Gettext

    assert gettext("Message {number}", number: 7) == "Message 7"
  end

  test "Compile time interpolation for translation" do
    Gettext.put_locale(MyApp.Gettext, "fr")
    Localize.put_locale(:fr)

    assert MyApp.Gettext.Use.translate_complex() == "Il est votre 2e jab"

    Gettext.put_locale(MyApp.Gettext, "en")
  end

  test "datetime interpolation" do
    use Gettext, backend: MyApp.Gettext
    Localize.put_locale(:en)

    assert gettext("Created at {created_at}", created_at: ~D[2022-01-22]) ==
             "Created at Jan 22, 2022"

    assert gettext("Created at {created_at}", created_at: ~U[2022-01-22T09:43:56.0Z]) ==
             "Created at Jan 22, 2022, 9:43:56 AM"

    assert gettext("Created at {created_at}", created_at: ~T[09:43:56]) ==
             "Created at 9:43:56 AM"
  end

  test "unit interpolation" do
    use Gettext, backend: MyApp.Gettext
    Localize.put_locale(:en)

    {:ok, weight} = Localize.Unit.new(23, "kilogram")

    assert gettext("It weighs {weight}", weight: weight) == "It weighs 23 kilograms"
    assert gettext("It weighs {weight, unit}", weight: weight) == "It weighs 23 kilograms"
  end

  describe "beyond ex_cldr_messages" do
    test "a runtime message that cannot be parsed is logged and returned unchanged" do
      log =
        capture_log(fn ->
          assert Localize.Message.MF1.Gettext.Interpolation.runtime_interpolate("{oops", %{}) ==
                   {:ok, "{oops"}
        end)

      assert log =~ "could not be parsed"
    end

    test "a value that cannot be formatted is logged and the message returned unchanged" do
      log =
        capture_log(fn ->
          assert Localize.Message.MF1.Gettext.Interpolation.runtime_interpolate(
                   "{n, number}",
                   %{n: "x"}
                 ) == {:ok, "{n, number}"}
        end)

      assert log =~ "returning"
    end

    test "a translation that is not MF1 is a compile error" do
      for message <- ["{oops", quote(do: some_function())] do
        assert_raise ArgumentError, fn ->
          Code.eval_quoted(
            quote do
              require Localize.Message.MF1.Gettext.Interpolation

              Localize.Message.MF1.Gettext.Interpolation.compile_interpolate(
                :translation,
                unquote(message),
                %{}
              )
            end
          )
        end
      end
    end

    test "a translation is parsed at compile time, and may be a concatenation of literals" do
      for message <- ["Hi {name}", quote(do: "Hi " <> "{name}")] do
        {result, _binding} =
          Code.eval_quoted(
            quote do
              require Localize.Message.MF1.Gettext.Interpolation

              Localize.Message.MF1.Gettext.Interpolation.compile_interpolate(
                :translation,
                unquote(message),
                %{name: "Ann"}
              )
            end
          )

        assert result == {:ok, "Hi Ann"}
      end
    end

    test "an interpolated translation is a compile error" do
      name = "x"

      assert_raise ArgumentError, ~r/a string at compile time/, fn ->
        Code.eval_quoted(
          quote do
            require Localize.Message.MF1.Gettext.Interpolation

            Localize.Message.MF1.Gettext.Interpolation.compile_interpolate(
              :translation,
              unquote(quote(do: "Hi #{unquote(name)} #{var}")),
              %{}
            )
          end
        )
      end
    end

    test "the message format is icu-format" do
      assert Localize.Message.MF1.Gettext.Interpolation.message_format() == "icu-format"
    end
  end
end
