# MessageFormat 1 for Localize

**Status:** in progress, 2026-10-27

A port of the MessageFormat 1 half of `ex_cldr_messages` 2.0.1 (`~/Development/cldr/cldr_messages`, `lib/cldr/messages/v1`, the `Cldr.Message` API and `Cldr.Gettext.Interpolation`) onto Localize, asked for in [localize#60](https://github.com/elixir-localize/localize/issues/60) by a team moving from ex_cldr whose translations are MF1 in Crowdin.

## Decisions

* **Namespace `Localize.Message.MF1`** (user, 2026-10-27), as the issue proposed, beside Localize's MF2 `Localize.Message`.

* **`money` arguments format a `Money` struct through ex_money 6.x**, an optional dependency, since ex_money 6 is built on Localize (user, 2026-10-27).

* **No backend.** ex_cldr's backend modules and `use Cldr.Gettext.Interpolation, cldr_backend: …` have no Localize counterpart; locale and options are arguments, as everywhere in Localize.

* **No function raises on invalid input.** `ex_cldr_messages` formats with `to_string!/2`; the port uses the `{:ok, _} | {:error, _}` functions throughout, and only the `!` functions raise.

* **The parser is ported, the interpreter rewritten.** The NimbleParsec grammar carries over; formatting goes through `Localize.Number`, `Localize.Number.PluralRule`, `Localize.Date`, `Localize.Time`, `Localize.DateTime`, `Localize.Unit` and `Money`.

* **Compatibility with `ex_cldr_messages` comes first** (user, 2026-10-27). Its MF1 tests are ported with their expected results and pass; other options are forwarded to every formatter, an unconfigured `:name` style is an RBNF rule or number format, and an MF2 message is formatted by `Localize.Message`. Errors are Localize exceptions rather than `{module, message}` tuples.

## Tasks

* [ ] **Gettext interpolation** — an MF1 interpolation module for `Gettext.Backend`.

* [ ] **Documentation and release** — README, a guide on moving from `ex_cldr_messages`, CHANGELOG and the release review.

### Done

* [x] **Printer and helpers** — `canonical_message/2`, `jaro_distance/3` and the `~M` sigil (`Localize.Message.MF1.Sigils`), byte-identical to `ex_cldr_messages` wherever its output parses back to the same message, checked against its output for a corpus in `test/fixtures/cldr_messages_canonical.exs`. The parser now quotes `#` only in plural clauses, and honours quoting mid-text in them, as ICU does. 2026-10-27.

* [x] **Interpreter** — `format/3`, `format!/3`, `format_to_iolist/3`, `format_list/3` and `bindings/1` through Localize. The `ex_cldr_messages` MF1 tests pass unchanged apart from error shapes and a CLDR no-break space; skeletons (`::…`) are tagged by the parser and return an error. 2026-10-27.

* [x] **Parser** — the MF1 grammar and `Localize.Message.MF1.Parser.parse/2`, with no atoms made from message text, errors returned rather than raised, duplicate selectors rejected, ICU argument names in any script, and layout white space dropped at every depth. The `plural` `type:` option is not ported (not ICU, and never worked in `ex_cldr_messages`). 2026-10-27.

* [x] **Project setup** — `mix.exs`, CI on the standard matrix, the pre-commit hook, `.credo.exs`, STATUS, TODO and this plan. 2026-10-27.
