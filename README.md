# Localize MF1

ICU MessageFormat 1 for [Localize](https://hex.pm/packages/localize): arguments, formatted arguments and the `plural`, `select` and `selectordinal` selectors, formatted with Localize's locales, plural rules and formatters. It lets an application that moves from `ex_cldr` to Localize keep its existing MessageFormat 1 translations. Localize itself formats MessageFormat 2.

This library is under development and not yet released; see [TODO.md](https://github.com/elixir-localize/localize_mf1/blob/main/TODO.md) for its progress.

## Features

* **MessageFormat 1 syntax** — arguments, formatted arguments and the `plural`, `select` and `selectordinal` selectors, as in ICU and `ex_cldr_messages` 1.x.

* **Localize formatting** — numbers, currencies, dates, times, units and plural categories come from Localize's CLDR data.

* **No backend module** — the locale and formatting options are arguments.

## Supported Elixir and OTP versions

Localize MF1 supports **Elixir 1.17** and later on **OTP 26** and later.

## Installation

```elixir
def deps do
  [
    {:localize_mf1, "~> 0.1"}
  ]
end
```

## Documentation

The documentation is published on [HexDocs](https://hexdocs.pm/localize_mf1).

## License

Localize MF1 is released under the [Apache License 2.0](https://github.com/elixir-localize/localize_mf1/blob/main/LICENSE.md).
