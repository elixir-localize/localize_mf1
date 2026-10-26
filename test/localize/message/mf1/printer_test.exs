defmodule Localize.Message.MF1.PrinterTest do
  # The tests of `ex_cldr_messages` 2.0.1 `test/print_test.exs`, ported with
  # their expected results.
  use ExUnit.Case, async: true

  alias Localize.Message.MF1.Parser
  alias Localize.Message.MF1.Printer

  defp round_trip(message) do
    {:ok, parsed} =
      message
      |> String.trim()
      |> Parser.parse()

    {:ok, parsed2} =
      parsed
      |> Printer.to_string()
      |> Parser.parse()

    {:ok, parsed3} =
      parsed
      |> Printer.to_string(pretty: true)
      |> Parser.parse()

    assert parsed2 == parsed
    assert parsed3 == parsed
  end

  test "to_string" do
    round_trip("""
     {gender_of_host, select,
        female {
          {num_guests, plural, offset: 1
            =0 {{host} does not give a party.}
            =1 {{host} invites {guest} to her party.}
            =2 {{host} invites {guest} and one other person to her party.}
            other {{host} invites {guest} and # other people to her party.}}}
        male {
          {num_guests, plural, offset: 1
            =0 {{host} does not give a party.}
            =1 {{host} invites {guest} to his party.}
            =2 {{host} invites {guest} and one other person to his party.}
            other {{host} invites {guest} and # other people to his party.}}}
        other {
          {num_guests, plural, offset: 1
            =0 {{host} does not give a party.}
            =1 {{host} invites {guest} to their party.}
            =2 {{host} invites {guest} and one other person to their party.}
            other {{host} invites {guest} and # other people to their party.}}}}
    """)
  end

  test "to_string when there is syntax literals" do
    round_trip("'{foo}'")
  end

  # Messages whose canonical form differs from that of `ex_cldr_messages`
  # because the original printed text that does not parse back to the same
  # message, so no working msgid has it.
  @divergent %{
    "This '{isn''t}' obvious" => "the original left the braces unquoted",
    "# items" => "the original quoted the #, which outside a plural is text",
    "{n, number, :spellout_ordinal}" => "the original dropped the colon of a named format",
    "{n, plural, other {'#'}}" => "the original read a quoted # in a plural as the number",
    "{n, plural, other {a '#' b}}" => "the original read a quoted # in a plural as the number",
    "{a, select, x { {b, plural, one {#} other {##}}} other {o}}" =>
      "the original printed a nested plural with no comma",
    "{a, select, other {{b, plural, other {#}}}}" =>
      "the original printed a nested plural with no comma"
  }

  @oracle "test/fixtures/cldr_messages_canonical.exs"
          |> Code.eval_file()
          |> elem(0)

  test "canonical forms are those of ex_cldr_messages" do
    for {message, compact, pretty} <- @oracle,
        not Map.has_key?(@divergent, message),
        {expected, options} <- [{compact, []}, {pretty, [pretty: true]}] do
      ours = Localize.Message.MF1.canonical_message(message, options)

      case expected do
        {:ok, _canonical} ->
          assert ours == expected, "#{inspect(message)} #{inspect(options)}"

        _failed ->
          assert {:ok, canonical} = ours
          assert {:ok, _parsed} = Parser.parse(canonical)
      end
    end
  end

  test "divergent canonical forms parse back to the same message" do
    for {message, _compact, _pretty} <- @oracle, Map.has_key?(@divergent, message) do
      {:ok, parsed} = Parser.parse(message)

      for options <- [[], [pretty: true]] do
        {:ok, canonical} = Localize.Message.MF1.canonical_message(message, options)
        assert Parser.parse(canonical) == {:ok, parsed}, "#{inspect(message)} #{inspect(options)}"
      end
    end
  end

  test "printing never raises and round-trips compact output" do
    messages = [
      "",
      "plain",
      "}{",
      "'{' and '}' and '' and '#'",
      "{n, plural, offset:1 =3 {x} other {# '{' # ''}}",
      "{n, selectordinal, offset:2 other {a}}",
      "{d, time, ::Hm}",
      "{v, number, '#'0}"
    ]

    for message <- messages, {:ok, parsed} <- [Parser.parse(message)] do
      printed = Printer.to_string(parsed)
      assert Parser.parse(printed) == {:ok, parsed}, inspect(message)
      assert is_binary(Printer.to_string(parsed, pretty: true))
    end
  end
end
