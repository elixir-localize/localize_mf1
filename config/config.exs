import Config

# Localize is configured here for this project's own dev and test
# environments only; consumers of the hex package configure their own.
# The `mix test` alias runs `mix localize.download_locales`, which reads
# this list, so it lives here rather than in a test-only config. The
# locales cover plural rules with every category count: `ja` (other only),
# `en` and `de` (one, other), `fr` (one, many, other), `ru` (one, few,
# many, other) and `ar` (zero, one, two, few, many, other).
config :localize,
  supported_locales: ~w(en fr de ar ru ja)

# ex_money (an optional dependency) need not fetch exchange rates here.
config :ex_money, auto_start_exchange_rate_service: false
