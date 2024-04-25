defmodule Avrogen.Utils.MacroUtils do
  @moduledoc """
    Utilities for working with code generation for the Avro schemas
  """

  @doc """
    This function flattens blocks of code together to avoid additional nesting and strange
    behaviour in generated code.
  """
  def flatten_block(ast) when is_list(ast), do: Enum.flat_map(ast, &flatten_block/1)
  def flatten_block({:__block__, [], block}), do: block
  def flatten_block(other), do: [other]

  @doc """
    This macro generated the implementation of Jason.Encoder which skips the encoding of
    `nil` valued fields.
  """
  defmacro jason_decode_skip_null_impl(type) do
    quote do
      defimpl Jason.Encoder, for: unquote(type) do
        def encode(%unquote(type){} = value, opts) do
          value
          |> Map.from_struct()
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
          |> Jason.Encode.map(opts)
        end
      end
    end
  end
end
