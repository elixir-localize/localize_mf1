# Changelog

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.0] — 2026-10-27

### Highlights

* **MessageFormat 1 for Localize** — `Localize.Message.MF1.format/3` formats arguments, formatted arguments and `plural`, `select` and `selectordinal` with Localize's locales and formatters, and money with `ex_money` 6.

* **A port of `ex_cldr_messages`** — the same API, options, output and canonical msgids, with the differences listed in the [migration guide](https://hexdocs.pm/localize_mf1/migrating_from_ex_cldr_messages.html).

* **Gettext and canonical messages** — `Localize.Message.MF1.Gettext.Interpolation`, `canonical_message/2`, `jaro_distance/3` and the `~M` sigil.

See the [README](https://hexdocs.pm/localize_mf1/readme.html) for the full documentation.
