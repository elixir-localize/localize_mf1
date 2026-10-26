defmodule Localize.Message.MF1.SigilsTest do
  # The tests of `ex_cldr_messages` 2.0.1 `test/sigil_test.exs`, ported with
  # their expected results.
  use ExUnit.Case, async: true

  import Localize.Message.MF1.Sigils

  doctest Localize.Message.MF1.Sigils

  # The message has trailing white space on purpose, as in the original test,
  # and `~M` takes no escapes, so it cannot be written another way.
  # credo:disable-for-lines:15 Credo.Check.Readability.TrailingWhiteSpace
  test "sigil_M" do
    assert ~M"{0} {1, plural,
  one {est

    
    {2, select, 
      female {allée}
      other {allé}}}
  other {sont

    
    {2, select, 
      female {allées}
      other {allés}}}} à {3}" ==
             "{0} {1, plural,\n  one {est\n\n    \n    {2, select, \n      female {allée}\n      other {allé}}}\n  other {sont\n\n    \n    {2, select, \n      female {allées}\n      other {allés}}}} à {3}"
  end

  test "sigil_m" do
    assert ~m"{0} {1, plural,
      one {est {2, select, female {allée} other  {allé}}}
      other {sont {2, select, female {allées} other {allés}}}
    } à {3}" ==
             "{0} {1, plural,\n  one {est \n    {2, select, \n      female {allée}\n      other {allé}}}\n  other {sont \n    {2, select, \n      female {allées}\n      other {allés}}}} à {3}"
  end

  test "sigil_m with pretty printing" do
    assert ~m"{0} {1, plural,
      one {est {2, select, female {allée} other  {allé}}}
      other {sont {2, select, female {allées} other {allés}}}
    } à {3}"p ==
             "{0} {1, plural,\n  one {est \n    {2, select, \n      female {allée}\n      other {allé}}}\n  other {sont \n    {2, select, \n      female {allées}\n      other {allés}}}} à {3}"
  end

  test "sigil_m with interpolation" do
    var = "{0}"

    assert ~m"#{var} {1, plural,
      one {est {2, select, female {allée} other  {allé}}}
      other {sont {2, select, female {allées} other {allés}}}
    } à {3}" ==
             "{0} {1, plural,\n  one {est \n    {2, select, \n      female {allée}\n      other {allé}}}\n  other {sont \n    {2, select, \n      female {allées}\n      other {allés}}}} à {3}"
  end

  test "an MF2 message is canonicalized by Localize.Message" do
    assert ~M"{{Hello {$name}}}" == Localize.Message.canonical_message!("{{Hello {$name}}}")
  end
end
