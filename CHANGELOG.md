# Changelog

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.2.0] — Unreleased

### Added

* Date, time and datetime skeletons: `{d, date, ::yMMMd}`, `{t, time, ::Hm}` and `{dt, datetime, ::yMMMdHm}` are matched to the locale's formats by Localize, with no atom made of the skeleton. Number skeletons remain unsupported.

### Changed

* Requires `localize ~> 1.9`, which takes a skeleton as text.

* An MF2 message given to `Localize.Message.MF1.format/3` is formatted with Localize 1.8's default bidi isolation, so a placeholder's text is wrapped in U+2068 and U+2069; MF1 messages are unchanged.

## [v0.1.0] — 2026-10-27

### Highlights

* **MessageFormat 1 for Localize** — `Localize.Message.MF1.format/3` formats arguments, formatted arguments and `plural`, `select` and `selectordinal` with Localize's locales and formatters, and money with `ex_money` 6.

* **A port of `ex_cldr_messages`** — the same API, options, output and canonical msgids, with the differences listed in the [migration guide](https://hexdocs.pm/localize_mf1/migrating_from_ex_cldr_messages.html).

* **Gettext and canonical messages** — `Localize.Message.MF1.Gettext.Interpolation`, `canonical_message/2`, `jaro_distance/3` and the `~M` sigil.

See the [README](https://hexdocs.pm/localize_mf1/readme.html) for the full documentation.
