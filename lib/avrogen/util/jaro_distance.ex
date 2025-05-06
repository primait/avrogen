defmodule Avrogen.Util.JaroDistance do
  @moduledoc """
  This is the exact implementation of `String.jaro_distance/2` before Elixir 1.17.1 when it was
  "fixed" for certain edge cases. Unfortunately, that fix broke a common case that we relied on
  (see issue 31 for examples).
  The simplest solution is just to keep using the old implementation. 
  """

  @spec jaro_distance(binary(), binary()) :: float()
  def jaro_distance(string1, string2)

  def jaro_distance(string, string), do: 1.0
  def jaro_distance(_string, ""), do: 0.0
  def jaro_distance("", _string), do: 0.0

  def jaro_distance(string1, string2) when is_binary(string1) and is_binary(string2) do
    {chars1, len1} = graphemes_and_length(string1)
    {chars2, len2} = graphemes_and_length(string2)

    case match(chars1, len1, chars2, len2) do
      {0, _trans} ->
        0.0

      {comm, trans} ->
        (comm / len1 + comm / len2 + (comm - trans) / comm) / 3
    end
  end

  defp match(chars1, len1, chars2, len2) do
    if len1 < len2 do
      match(chars1, chars2, div(len2, 2) - 1)
    else
      match(chars2, chars1, div(len1, 2) - 1)
    end
  end

  defp match(chars1, chars2, lim) do
    match(chars1, chars2, {0, lim}, {0, 0, -1}, 0)
  end

  defp match([char | rest], chars, range, state, idx) do
    {chars, state} = submatch(char, chars, range, state, idx)

    case range do
      {lim, lim} -> match(rest, tl(chars), range, state, idx + 1)
      {pre, lim} -> match(rest, chars, {pre + 1, lim}, state, idx + 1)
    end
  end

  defp match([], _, _, {comm, trans, _}, _), do: {comm, trans}

  defp submatch(char, chars, {pre, _} = range, state, idx) do
    case detect(char, chars, range) do
      nil ->
        {chars, state}

      {subidx, chars} ->
        {chars, proceed(state, idx - pre + subidx)}
    end
  end

  defp detect(char, chars, {pre, lim}) do
    detect(char, chars, pre + 1 + lim, 0, [])
  end

  defp detect(_char, _chars, 0, _idx, _acc), do: nil
  defp detect(_char, [], _lim, _idx, _acc), do: nil

  defp detect(char, [char | rest], _lim, idx, acc), do: {idx, Enum.reverse(acc, [nil | rest])}

  defp detect(char, [other | rest], lim, idx, acc),
    do: detect(char, rest, lim - 1, idx + 1, [other | acc])

  defp proceed({comm, trans, former}, current) do
    if current < former do
      {comm + 1, trans + 1, current}
    else
      {comm + 1, trans, current}
    end
  end

  defp graphemes_and_length(string),
    do: graphemes_and_length(string, [], 0)

  defp graphemes_and_length(string, acc, length) do
    case :unicode_util.gc(string) do
      [gc | rest] ->
        graphemes_and_length(rest, [gc | acc], length + 1)

      [] ->
        {:lists.reverse(acc), length}

      {:error, <<byte, rest::bits>>} ->
        graphemes_and_length(rest, [<<byte>> | acc], length + 1)
    end
  end
end
