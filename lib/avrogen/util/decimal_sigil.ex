defmodule Avrogen.Decimal.Sigil do
  @moduledoc """
  Sigil for the `Decimal` type.
  """
  def sigil_d(string, []), do: Decimal.new(string)
end
