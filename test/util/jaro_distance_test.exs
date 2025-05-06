defmodule Avrogen.Util.JaroDistance.Test do
  use ExUnit.Case, async: true

  test "jaro_distance/2" do
    assert String.jaro_distance("same", "same") == 1.0
    assert String.jaro_distance("any", "") == 0.0
    assert String.jaro_distance("", "any") == 0.0
    assert String.jaro_distance("martha", "marhta") == 0.9444444444444445
    assert String.jaro_distance("martha", "marhha") == 0.888888888888889
    assert String.jaro_distance("marhha", "martha") == 0.888888888888889
    assert String.jaro_distance("dwayne", "duane") == 0.8222222222222223
    assert String.jaro_distance("dixon", "dicksonx") == 0.7666666666666666
    assert String.jaro_distance("xdicksonx", "dixon") == 0.7851851851851852
    assert String.jaro_distance("shackleford", "shackelford") == 0.9696969696969697
    assert String.jaro_distance("dunningham", "cunnigham") == 0.8962962962962964
    assert String.jaro_distance("nichleson", "nichulson") == 0.9259259259259259
    assert String.jaro_distance("jones", "johnson") == 0.7904761904761904
    assert String.jaro_distance("massey", "massie") == 0.888888888888889
    assert String.jaro_distance("abroms", "abrams") == 0.888888888888889
    assert String.jaro_distance("hardin", "martinez") == 0.7222222222222222
    assert String.jaro_distance("itman", "smith") == 0.4666666666666666
    assert String.jaro_distance("jeraldine", "geraldine") == 0.9259259259259259
    assert String.jaro_distance("michelle", "michael") == 0.8690476190476191
    assert String.jaro_distance("julies", "julius") == 0.888888888888889
    assert String.jaro_distance("tanya", "tonya") == 0.8666666666666667
    assert String.jaro_distance("sean", "susan") == 0.7833333333333333
    assert String.jaro_distance("jon", "john") == 0.9166666666666666
    assert String.jaro_distance("jon", "jan") == 0.7777777777777777
    assert String.jaro_distance("семена", "стремя") == 0.6666666666666666
  end
end
