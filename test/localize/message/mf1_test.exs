defmodule Localize.Message.MF1Test do
  use ExUnit.Case, async: true

  doctest Localize.Message.MF1

  test "a value that is not a string is not an MF2 message" do
    for value <- [nil, 42, %{}, :atom, ["{{x}}"]] do
      refute Localize.Message.MF1.mf2?(value)
    end
  end
end
