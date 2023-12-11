defmodule Avrogen.Util.FuzzyEnumMatch do
  @moduledoc """
  Fuzzy enum matching.
  """
  def preprocess(s) when is_binary(s) do
    normalised =
      s
      |> String.downcase()
      |> String.trim()
      |> String.replace(~r"[^0-9a-zA-Z]+", "_")
      |> String.replace(~r"^_", "")
      |> String.replace(~r"_$", "")

    canonical = "__" <> normalised <> "_"

    trigrams =
      canonical
      |> String.graphemes()
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(fn trigram -> Enum.join(trigram) end)

    {s, canonical, trigrams}
  end

  def make_index(atoms) do
    Enum.reduce(atoms, %{}, fn atom, trigram_index ->
      {_, canonical, trigrams} = preprocess(Atom.to_string(atom))

      Enum.reduce(trigrams, trigram_index, fn trigram, index ->
        Map.update(
          index,
          trigram,
          MapSet.new([{canonical, atom}]),
          &MapSet.put(&1, {canonical, atom})
        )
      end)
    end)
  end

  @empty MapSet.new()

  def candidates(index, s) do
    {_, canonical, trigrams} = preprocess(s)

    Enum.reduce(trigrams, MapSet.new(), fn trigram, candidates ->
      MapSet.union(candidates, Map.get(index, trigram, @empty))
    end)
    |> Enum.map(fn {c, orig} -> {c, String.jaro_distance(canonical, c), orig} end)
    |> Enum.sort_by(fn {_, similarity, _} -> similarity end, :desc)
  end

  @doc """
  Returns the closest match for s from the lookup index; returns the default
  value if the similarity is less than the given threshold or if s is not a
  string.
  """
  def best_match(index, s, default_value, min_similarity \\ 0.5)

  def best_match(index, s, default_value, min_similarity) when is_binary(s) do
    candidates(index, s)
    |> Enum.take(1)
    |> case do
      [{_, sim, atom}] when sim >= min_similarity -> atom
      _ -> default_value
    end
  end

  def best_match(_, _, default_value, _), do: default_value
end
