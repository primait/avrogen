defmodule Avro.Decimal.Sigil do
  def sigil_d(string, []), do: Decimal.new(string)
end
