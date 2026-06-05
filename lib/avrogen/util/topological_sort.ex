defmodule Avrogen.Util.TopologicalSort do
  @moduledoc nil

  def topological_sort(vertices, edges) do
    Graph.new()
    |> Graph.add_vertices(vertices)
    |> Graph.add_edges(edges)
    |> Graph.topsort()
    |> case do
      false -> {:error, :cyclic_dependencies}
      sorted -> {:ok, sorted}
    end
  end
end
