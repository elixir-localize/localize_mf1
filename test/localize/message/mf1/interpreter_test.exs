defmodule Localize.Message.MF1.InterpreterTest do
  use ExUnit.Case, async: true

  alias Localize.Message.MF1

  describe "arguments and bindings" do
    test "map bindings with string or atom keys" do
      assert MF1.format("{a} {b}", %{"a" => 1, b: "two"}) == {:ok, "1 two"}
    end

    test "a binding name in any script" do
      assert MF1.format("{名前}", %{"名前" => "x"}) == {:ok, "x"}
    end

    test "positional arguments from a map with integer or string keys" do
      assert MF1.format("{0} {1}", %{0 => "a", "1" => "b"}) == {:ok, "a b"}
    end

    test "no atom is made from an argument name" do
      name = "no_atom_for_this_name_#{System.unique_integer([:positive])}"
      assert {:error, %Localize.BindError{}} = MF1.format("{#{name}}", [])
      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end

    test "an unbound argument is an error, and is written as its source in an iolist" do
      assert MF1.format("Hello {name} {0}", []) ==
               {:error, Localize.BindError.exception(unbound: ["name", 0])}

      assert MF1.format_to_iolist("Hi {name}, {other}", other: "x") ==
               {:error, ["Hi ", "{name}", ", ", "x"], ["other"], ["name"]}
    end

    test "an unbound selector is reported and its clauses are not formatted" do
      assert MF1.format_to_iolist("{n, plural, other {{x}}}", []) ==
               {:error, ["{n}"], [], ["n"]}
    end

    test "a message from a parsed message" do
      {:ok, parsed} = MF1.Parser.parse("{n, number, percent}")
      assert MF1.format_list(parsed, n: 0.5) == {:ok, ["50%"], ["n"], []}
    end
  end

  describe "locales" do
    test "the locale option" do
      assert MF1.format("{n}", [n: 1234.5], locale: :de) == {:ok, "1.234,5"}
    end

    test "plural categories of the locale" do
      message = "{n, plural, zero {z} one {o} two {t} few {f} many {m} other {x}}"

      assert MF1.format(message, [n: 3], locale: :ar) == {:ok, "f"}
      assert MF1.format(message, [n: 2], locale: :ru) == {:ok, "f"}
      assert MF1.format(message, [n: 5], locale: :ru) == {:ok, "m"}
    end

    test "an invalid locale is an error" do
      assert {:error, %Localize.InvalidLocaleError{}} =
               MF1.format("{n}", [n: 1], locale: "zz-Bogus")
    end
  end

  describe "plural" do
    test "a fraction selects by its CLDR category, not by its integer part" do
      message = "{n, plural, one {# item} other {# items}}"

      assert MF1.format(message, n: 1.5) == {:ok, "1.5 items"}
      assert MF1.format(message, n: Decimal.new("1.5")) == {:ok, "1.5 items"}
    end

    test "an explicit value matches an equal float or Decimal" do
      message = "{n, plural, =1 {exactly one} other {#}}"

      assert MF1.format(message, n: 1.0) == {:ok, "exactly one"}
      assert MF1.format(message, n: Decimal.new("1.00")) == {:ok, "exactly one"}
    end

    test "# is formatted for the locale, after the offset" do
      assert MF1.format("{n, plural, offset:1 other {# more}}", [n: 1235], locale: :de) ==
               {:ok, "1.234 more"}
    end

    test "a value that is not a number is an error" do
      assert {:error, %Localize.FormatError{}} =
               MF1.format("{n, plural, other {#}}", n: "three")
    end

    test "# in a select nested in a plural is literal, as in ICU" do
      assert MF1.format("{n, plural, other {{g, select, other {#}}}}", n: 2, g: "x") ==
               {:ok, "#"}
    end
  end

  describe "select" do
    test "atom and integer values choose their clause" do
      message = "{g, select, female {She} 1 {One} other {They}}"

      assert MF1.format(message, g: :female) == {:ok, "She"}
      assert MF1.format(message, g: 1) == {:ok, "One"}
      assert MF1.format(message, g: %{}) == {:ok, "They"}
    end
  end

  describe "number arguments" do
    test "styles" do
      assert MF1.format("{n, number, integer}", n: 1234.6) == {:ok, "1235"}
      assert MF1.format("{n, number, currency}", [n: 3], currency: :EUR) == {:ok, "€3.00"}
      assert MF1.format("{n, number, permille}", n: 0.0123) == {:ok, "12‰"}
      assert MF1.format("{n, number, short}", n: 12_345) == {:ok, "12K"}
      assert MF1.format("{n, number, #,##0.00}", n: 3) == {:ok, "3.00"}
    end

    test "a named format from the :formats option" do
      formats = %{two_places: [fractional_digits: 2]}

      assert MF1.format("{n, number, :two_places}", [n: 3], formats: formats) == {:ok, "3.00"}
    end

    test "an unknown named format, a skeleton and a style of another type are errors" do
      assert {:error, %Localize.FormatError{}} = MF1.format("{n, number, :nope}", n: 1)
      assert {:error, %Localize.FormatError{}} = MF1.format("{n, number, ::percent}", n: 1)
      assert {:error, _exception} = MF1.format("{n, number, medium}", n: 1)
    end

    test "a value that is not a number is an error" do
      assert {:error, %Localize.FormatError{}} = MF1.format("{n, number}", n: "x")
    end
  end

  describe "spellout and ordinal arguments" do
    test "spellout styles" do
      assert MF1.format("{n, spellout}", n: 42) == {:ok, "forty-two"}
      assert MF1.format("{n, spellout, ordinal}", n: 2) == {:ok, "second"}
      assert MF1.format("{n, spellout, year}", n: 1999) == {:ok, "nineteen ninety-nine"}
      assert MF1.format("{n, spellout, %spellout-cardinal}", n: 3) == {:ok, "three"}
    end

    test "ordinal" do
      assert MF1.format("{n, ordinal}", n: 22) == {:ok, "22nd"}
    end

    test "an unknown rule is an error" do
      assert {:error, _exception} = MF1.format("{n, spellout, %nope}", n: 3)
    end
  end

  describe "date and time arguments" do
    test "default, keyword and pattern styles" do
      date = ~D[2026-10-27]

      assert MF1.format("{d, date}", d: date) == {:ok, "Oct 27, 2026"}
      assert MF1.format("{d, date, short}", d: date) == {:ok, "10/27/26"}
      assert MF1.format("{d, date, yyyy/MM}", d: date) == {:ok, "2026/10"}
      assert MF1.format("{t, time, short}", t: ~T[13:04:00]) == {:ok, "1:04 PM"}

      assert MF1.format("{dt, datetime, short}", dt: ~U[2026-10-27 13:04:00Z]) ==
               {:ok, "10/27/26, 1:04 PM"}
    end

    test "a skeleton or a value that is not a date is an error" do
      assert {:error, %Localize.FormatError{}} =
               MF1.format("{d, date, ::yMMMd}", d: ~D[2026-10-27])

      assert {:error, _exception} = MF1.format("{d, date}", d: "today")
    end
  end

  describe "unit, list and money arguments" do
    test "unit styles" do
      {:ok, unit} = Localize.Unit.new(3, "kilometer")

      assert MF1.format("{u, unit}", u: unit) == {:ok, "3 kilometers"}
      assert MF1.format("{u, unit, short}", u: unit) == {:ok, "3 km"}
      assert MF1.format("{u, unit, narrow}", u: unit) == {:ok, "3km"}
    end

    test "list styles" do
      assert MF1.format("{l, list}", l: ["a", "b", "c"]) == {:ok, "a, b, and c"}
      assert MF1.format("{l, list, or}", l: ["a", "b", "c"]) == {:ok, "a, b, or c"}
    end

    test "money styles" do
      money = Money.new(:USD, 1234)

      assert MF1.format("{m, money}", m: money) == {:ok, "$1,234.00"}
      assert MF1.format("{m, money, long}", m: money) == {:ok, "1,234.00 US dollars"}
    end

    test "values of the wrong type are errors" do
      assert {:error, _exception} = MF1.format("{u, unit}", u: 3)
      assert {:error, _exception} = MF1.format("{l, list}", l: 3)
      assert {:error, %Localize.FormatError{}} = MF1.format("{m, money}", m: 3)
    end
  end

  describe "MessageFormat 2" do
    test "an MF2 message is formatted by Localize.Message" do
      assert MF1.format("{{Hello {$name}}}", name: "World") == {:ok, "Hello World"}
    end
  end

  describe "invalid input" do
    test "messages, bindings and options of the wrong type are errors" do
      assert {:error, %Localize.InvalidValueError{}} = MF1.format(nil)
      assert {:error, %Localize.InvalidValueError{}} = MF1.format("{a}", :bindings)
      assert {:error, %Localize.InvalidValueError{}} = MF1.format("{a}", [a: 1], :options)
      assert {:error, %Localize.InvalidValueError{}} = MF1.format_list(:parsed)
      assert {:error, %Localize.InvalidValueError{}} = MF1.bindings(42)
    end

    test "format!/3 raises the error" do
      assert_raise Localize.BindError, fn -> MF1.format!("{a}") end
      assert_raise MF1.ParseError, fn -> MF1.format!("{a") end
    end

    test "unusual values never raise" do
      values = [
        nil,
        :atom,
        {1, 2},
        %{},
        [1, [2]],
        self(),
        make_ref(),
        fn -> 1 end,
        <<255>>,
        1.0e300
      ]

      messages = [
        "{v}",
        "{v, number}",
        "{v, number, integer}",
        "{v, spellout}",
        "{v, ordinal}",
        "{v, date}",
        "{v, time, short}",
        "{v, datetime}",
        "{v, unit}",
        "{v, list}",
        "{v, money}",
        "{v, plural, other {#}}",
        "{v, selectordinal, other {#}}",
        "{v, select, other {x}}"
      ]

      for value <- values, message <- messages do
        assert {status, _result} = MF1.format(message, v: value)
        assert status in [:ok, :error]
      end
    end
  end

  describe "named formats" do
    setup do
      previous = Application.get_env(:localize_mf1, :formats)
      Application.put_env(:localize_mf1, :formats, %{env_one_place: [fractional_digits: 1]})

      on_exit(fn ->
        if is_nil(previous) do
          Application.delete_env(:localize_mf1, :formats)
        else
          Application.put_env(:localize_mf1, :formats, previous)
        end
      end)
    end

    test "a format from the application environment" do
      assert MF1.format("{n, number, :env_one_place}", n: 3) == {:ok, "3.0"}
    end

    test "a number format style of the locale by name" do
      assert MF1.format("{n, number, :decimal_long}", n: 12_000) == {:ok, "12 thousand"}
    end

    test "an RBNF rule by name for spellout" do
      assert MF1.format("{n, spellout, :spellout_cardinal}", n: 3) == {:ok, "three"}
    end

    test "configured formats for dates, units, lists and money" do
      formats = [
        short_date: [format: :short],
        abbreviated: [format: :short],
        wide: [format: :long]
      ]

      {:ok, unit} = Localize.Unit.new(3, "kilometer")

      assert MF1.format("{d, date, :short_date}", [d: ~D[2026-10-27]], formats: formats) ==
               {:ok, "10/27/26"}

      assert MF1.format("{u, unit, :abbreviated}", [u: unit], formats: formats) == {:ok, "3 km"}

      assert MF1.format("{m, money, :wide}", [m: Money.new(:USD, 2)], formats: formats) ==
               {:ok, "2.00 US dollars"}
    end

    test "an unconfigured name or another keyword style formats with the defaults" do
      assert MF1.format("{d, date, :nothing}", d: ~D[2026-10-27]) == {:ok, "Oct 27, 2026"}
      assert MF1.format("{d, date, integer}", d: ~D[2026-10-27]) == {:ok, "Oct 27, 2026"}
      assert MF1.format("{l, list, :nothing}", l: ["a", "b"]) == {:ok, "a and b"}
      assert MF1.format("{l, list, short}", l: ["a", "b"]) == {:ok, "a and b"}
    end

    test "formats that are not a map or keyword list, or not keyword entries, are ignored" do
      assert MF1.format("{n, number, :env_one_place}", [n: 3], formats: :bad) == {:ok, "3.0"}

      assert MF1.format("{n, number, :env_one_place}", [n: 3], formats: %{env_one_place: :bad}) ==
               {:ok, "3.0"}
    end

    test "pattern text a type does not take, and a style spellout does not take, are errors" do
      {:ok, unit} = Localize.Unit.new(3, "kilometer")

      assert {:error, %Localize.FormatError{}} = MF1.format("{u, unit, wide}", u: unit)
      assert {:error, %Localize.FormatError{}} = MF1.format("{n, spellout, medium}", n: 3)
    end
  end

  describe "edge cases" do
    test "a plain number with formatter options" do
      assert MF1.format("{n}", n: {3, fractional_digits: 2}) == {:ok, "3.00"}
    end

    test "a Decimal with an offset" do
      assert MF1.format("{n, plural, offset:1 other {#}}", n: Decimal.new(3)) == {:ok, "2"}
    end

    test "named arguments are not found in a list of values or under other keys" do
      assert {:error, %Localize.BindError{}} = MF1.format("{a}", ["x"])
      assert {:error, %Localize.BindError{}} = MF1.format("{a}", %{1 => "x"})
    end

    test "a hand-built parsed message" do
      assert MF1.format_list([:value], []) == {:ok, ["#"], [], []}

      assert MF1.format_list([{:plural, {:named_arg, "n"}, [], %{}}], n: 1) ==
               {:ok, [], ["n"], []}

      assert {:error, %Localize.FormatError{}} =
               MF1.format_list([{:simple_format, {:named_arg, "a"}, :bogus}], a: 1)

      assert {:error, %Localize.FormatError{}} = MF1.format_list([{:bogus}], [])
    end

    test "the :trim option" do
      assert MF1.format("  {a}  ", [a: 1], trim: true) == {:ok, "1"}
    end

    test "errors for a message that is not a string" do
      assert {:error, %Localize.InvalidValueError{}} = MF1.format_to_iolist(nil)
      {:error, error} = MF1.Parser.parse(42)
      assert Exception.message(error) =~ "could not be parsed: a message is a string"
    end
  end
end
