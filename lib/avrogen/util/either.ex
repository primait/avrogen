defmodule Avrogen.Util.Either do
  @moduledoc """
  Fancy implementation of Either monad.
  """

  @type either :: {:ok, any()} | {:error, any()}
  @type fun :: (any() -> any())

  @spec map(either(), fun()) :: either()
  def map({:ok, something}, function), do: {:ok, function.(something)}
  def map({:error, something}, _function), do: {:error, something}
end
