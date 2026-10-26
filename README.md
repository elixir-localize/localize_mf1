# Localize MF1

ICU MessageFormat 1 for [Localize](https://hex.pm/packages/localize): arguments, formatted arguments and the `plural`, `select` and `selectordinal` selectors, formatted with Localize's locales, plural rules and formatters. It is a port of the MessageFormat 1 support in `ex_cldr_messages`, so an application that moves from `ex_cldr` to Localize keeps its MessageFormat 1 translations and msgids unchanged. Localize itself formats MessageFormat 2.

## Features

* **MessageFormat 1 syntax** — arguments, formatted arguments, the `plural`, `select` and `selectordinal` selectors with `offset:` and explicit `=n` clauses, `#`, and ICU apostrophe quoting.

* **Localize formatting** — numbers, currencies, spelled-out numbers, ordinals, dates, times, units, lists and plural categories from Localize's CLDR data, and money through `ex_money` 6 when it is a dependency.

* **Compatible with `ex_cldr_messages`** — the same API, options and output, so messages and canonical msgids carry over. The [migration guide](https://hexdocs.pm/localize_mf1/migrating_from_ex_cldr_messages.html) lists every difference.

* **Gettext interpolation** — `Localize.Message.MF1.Gettext.Interpolation` formats a Gettext backend's messages as MessageFormat 1.

* **Canonical messages** — `canonical_message/2` and the `~M` sigil give a message a canonical form for use as a msgid, and `jaro_distance/3` compares two messages.

* **No backend module** — the locale is Localize's, and formatting options are arguments.

* **Never raises on invalid input** — every function except the `!` functions returns `{:ok, result}` or `{:error, exception}`.

## Supported Elixir and OTP versions

Localize MF1 requires **Elixir 1.17+** and **Erlang/OTP 26+**.

On OTP 26, also add `{:json_polyfill, "~> 0.2 or ~> 1.0"}` to your dependencies. It provides the OTP 27+ `:json` module that Localize uses. OTP 27 and later need no extra dependency.

## Installation

Add `localize_mf1` to your dependencies in `mix.exs`, and `ex_money` if your messages format `money` arguments:

```elixir
def deps do
  [
    {:localize_mf1, "~> 0.1"},
    {:ex_money, "~> 6.0"}
  ]
end
```

Localize ships with the `en` locale. Download the data for any other locale your application uses at build time with `mix localize.download_locales`, for example `mix localize.download_locales fr de`. See [`mix localize.download_locales`](https://hexdocs.pm/localize/Mix.Tasks.Localize.DownloadLocales.html).

## Quick start

Arguments are bound by name, from a keyword list or a map, or by position:

```elixir
iex> Localize.Message.MF1.format("Hello {name}!", name: "World")
{:ok, "Hello World!"}

iex> Localize.Message.MF1.format("{0} and {1}", ["this", "that"])
{:ok, "this and that"}
```

Formatted arguments use Localize's formatters in the current locale, or the `:locale` option:

```elixir
iex> Localize.Message.MF1.format("{count, number} jelly beans", [count: 1234], locale: :de)
{:ok, "1.234 jelly beans"}

iex> Localize.Message.MF1.format("Due {due, date, long}", due: ~D[2026-10-27])
{:ok, "Due October 27, 2026"}
```

`plural` and `selectordinal` choose a clause by the locale's plural rules, and `select` by a value:

```elixir
iex> Localize.Message.MF1.format("{count, plural, =0 {no items} one {# item} other {# items}}", count: 3)
{:ok, "3 items"}

iex> Localize.Message.MF1.format("{place, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}", place: 22)
{:ok, "22nd"}

iex> Localize.Message.MF1.format("{gender, select, female {She} male {He} other {They}} replied", gender: "female")
{:ok, "She replied"}
```

A canonical form ignores layout white space, for use as a msgid:

```elixir
iex> Localize.Message.MF1.canonical_message("{count, plural,\n  other {# items}\n  one {# item}}")
{:ok, "{count, plural, one {# item} other {# items}}"}
```

## Gettext

Name the interpolation module in a Gettext backend, and its messages are formatted as MessageFormat 1:

```elixir
defmodule MyApp.Gettext do
  use Gettext.Backend,
    otp_app: :my_app,
    interpolation: Localize.Message.MF1.Gettext.Interpolation
end
```

The `~M` sigil of `Localize.Message.MF1.Sigils` canonicalizes a message at compile time, so a change of layout does not make a new msgid.

## Documentation

* **[Migrating from ex_cldr_messages](https://hexdocs.pm/localize_mf1/migrating_from_ex_cldr_messages.html)** — the API mapping and every difference in behaviour.

* **[Localize.Message.MF1](https://hexdocs.pm/localize_mf1/Localize.Message.MF1.html)** — formatting, the argument types and styles, named formats and canonical messages.

* **[Localize.Message.MF1.Gettext.Interpolation](https://hexdocs.pm/localize_mf1/Localize.Message.MF1.Gettext.Interpolation.html)** — Gettext interpolation.

The full documentation is published on [HexDocs](https://hexdocs.pm/localize_mf1).

## License

Localize MF1 is released under the [Apache License 2.0](https://github.com/elixir-localize/localize_mf1/blob/v0.1.0/LICENSE.md).
