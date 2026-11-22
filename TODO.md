# TODO

Work planned for `localize_mf1`. The design and its stages are in [plans/mf1-port.md](plans/mf1-port.md); shipped changes are in the [CHANGELOG](CHANGELOG.md).

## Done

* [x] **Date and time skeletons** — `{d, date, ::yMMMd}` formats through Localize's `format: {:skeleton, text}`; number skeletons stay unsupported. 2026-11-21, v0.2.0.

* [x] **Port MessageFormat 1 from `ex_cldr_messages`** — parser, interpreter, printer, Gettext interpolation and a migration guide, compatible with `ex_cldr_messages`; closes localize#60. 2026-10-27, v0.1.0.
