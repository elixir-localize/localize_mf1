# Migrating from ex_cldr_messages

`localize_mf1` is a port of the MessageFormat 1 support in `ex_cldr_messages` 2.0 onto Localize. Messages, and the msgids made from them, carry over unchanged: the tests of `ex_cldr_messages` pass against this library with their expected results, apart from the differences listed below. This guide maps the API and lists every difference.

## Dependencies

Replace `ex_cldr_messages` and the `ex_cldr` packages it used with `localize_mf1`. Add `ex_money` 6 if your messages format `money` arguments:

```elixir
def deps do
  [
    {:localize_mf1, "~> 0.1"},
    {:ex_money, "~> 6.0"}
  ]
end
```

Localize has no backend module. The locale is Localize's (`Localize.put_locale/1` instead of `Cldr.put_locale/2`), and the locales your application uses are downloaded at build time with `mix localize.download_locales`.

## The API

| ex_cldr_messages | localize_mf1 |
|---|---|
| `Cldr.Message.format/3`, `format!/3` | `Localize.Message.MF1.format/3`, `format!/3` |
| `Cldr.Message.format_to_iolist/3`, `format_list/3` | `Localize.Message.MF1.format_to_iolist/3`, `format_list/3` |
| `Cldr.Message.bindings/1` | `Localize.Message.MF1.bindings/1` |
| `Cldr.Message.canonical_message/2`, `canonical_message!/2` | `Localize.Message.MF1.canonical_message/2`, `canonical_message!/2` |
| `Cldr.Message.jaro_distance/3`, `jaro_distance!/3` | `Localize.Message.MF1.jaro_distance/3`, `jaro_distance!/3` |
| `Cldr.Message.Sigil` (`~M`) | `Localize.Message.MF1.Sigils` (`~M`) |
| `use Cldr.Gettext.Interpolation, cldr_backend: MyApp.Cldr` | `interpolation: Localize.Message.MF1.Gettext.Interpolation` |
| `MyApp.Cldr.Message.format/3` (a macro) | `Localize.Message.MF1.format/3` |
| the `message_formats:` backend option | the `:formats` option, or `config :localize_mf1, :formats` |

The `:backend` and `:formatter_backend` options no longer apply. Every other option is given to the formatters, as before:

```elixir
iex> Localize.Message.MF1.format("{price, number, currency}", [price: 12], currency: :EUR)
{:ok, "€12.00"}
```

A Gettext backend names the interpolation module directly; there is no module to define:

```elixir
defmodule MyApp.Gettext do
  use Gettext.Backend,
    otp_app: :my_app,
    interpolation: Localize.Message.MF1.Gettext.Interpolation
end
```

Named formats, configured on the ex_cldr backend with `message_formats:`, are given as an option or in the application environment:

```elixir
iex> Localize.Message.MF1.format("{n, number, :two_places}", [n: 3], formats: %{two_places: [fractional_digits: 2]})
{:ok, "3.00"}
```

## Unchanged behaviour

These behave as they did in `ex_cldr_messages`, so formatted messages stay the same:

* **Options reach every formatter** — so `currency: :EUR` given to `format/3` applies to every number in the message, not only to `{n, number, currency}`.

* **The `integer` style is the pattern `#`** — with no digit grouping.

* **`{n, number, ordinal}` is "1st"**, and a `:name` style that is not a configured format names an RBNF rule or a number format, so `{n, number, :spellout_ordinal}` is "first".

* **A number binding may be `{number, options}`** — as in `count: {1, currency: :MXP}`.

* **`bindings/1` lists names in the same order.**

* **Canonical forms are byte for byte the same** — wherever the original's form parses back to the same message, so msgids made by `~M` or `canonical_message/2` are unchanged. The exceptions are below.

* **An MF2 message given to `format/3` or `canonical_message/2` is handled by `Localize.Message`**, as `Cldr.Message` handled it. The Gettext interpolation module, like `Cldr.Gettext.Interpolation`, treats every message as MF1; use `Localize.Gettext.Interpolation` for MF2 messages.

## Differences

### Errors

* **Errors are exceptions** — a function returns `{:error, exception}` rather than `{:error, {module, message}}`. The exceptions are `Localize.Message.MF1.ParseError`, `Localize.Message.MF1.PositionalArgumentError`, `Localize.BindError`, `Localize.FormatError` and `Localize.InvalidValueError`.

* **Nothing raises on invalid input** except the `!` functions. A value that cannot be formatted, such as a string for `{n, number}`, is an error result where `ex_cldr_messages` raised.

* **The Gettext interpolation module logs a message that cannot be parsed or formatted at runtime** and returns it unchanged, where `ex_cldr_messages` raised. A translation in a `.po` file that is not MF1 is still a compile error.

* **An argument with no binding is written into `format_to_iolist/3`'s iolist as its source text**, such as `{n, number, currency}`, rather than as a tuple.

### Formatting

* **A fraction selects its plural category** — `{n, plural, one {# item} other {# items}}` with `n: 1.5` is "1.5 items". `ex_cldr_messages` truncated the number first and gave "1 items".

* **`select` matches an atom or integer value by its text** — `gender: :female` chooses the `female` clause, where `ex_cldr_messages` chose `other`.

* **Argument types that raised now format** — `{n, ordinal}` ("1st") and `{m, money}` with no style.

* **Skeletons are not supported** — `{n, number, ::currency/USD}` and `{d, date, ::yMMMd}` return a `Localize.FormatError`. They did not parse in `ex_cldr_messages`.

* **Formatted text follows Localize's CLDR data**, which is newer than that of `ex_cldr` 2.x: a time is "9:43:56 AM" with a narrow no-break space before "AM", and "MXP 1.00" has a no-break space.

### Syntax

* **Argument names may be in any script**, as in ICU: `{名前}` and `{straße}` are arguments.

* **A selector given twice is an error**, as in ICU; `ex_cldr_messages` kept one of them.

* **Quoting works inside `plural` and `selectordinal` clauses** — `It''s`, `'#'` and `'{'` there are an apostrophe, a `#` and a `{`. `ex_cldr_messages` ignored quoting in those clauses.

* **The `plural` `type:` option is not supported.** It is not part of ICU MessageFormat, and had no effect in `ex_cldr_messages`.

### Canonical forms

A canonical form differs from that of `ex_cldr_messages` only where the original's did not parse back to the same message, so no working msgid had it:

* **A literal with a brace after its first character** is quoted: `This '{isn''t}' obvious` was printed with its braces unquoted.

* **A literal starting with `#` outside a plural clause** is not quoted: `# items` was printed `'# items'`, whose apostrophes are text.

* **A named format** keeps its colon: `{n, number, :spellout_ordinal}` was printed without it, which is a pattern.

* **A `#` quoted in a plural clause** is printed `'#'`, not `''#''`.

* **A nested `plural` with no offset, pretty printed**, has its comma: `{b, plural,` was printed `{bplural,`.

Messages that `ex_cldr_messages` could not print at all now print: an empty message, an argument with a type and no style such as `{n, number}`, a `selectordinal` with an offset, and selectors nested more than five deep.
