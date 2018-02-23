# Generate rules that generates FLAG automatically
# 手動でcounter計算してフラグの組み合わせ書くの疲れた

# 文字ごとのcounter名とそれの最終的な数(FLAG), ランダムに組み合わせて生成したそれぞれのルールに使うマス（27, 39 !31, etc...), それぞれのマスのON/OFFを与えれば、z3に解かせてルールに合致したときにincrementするcounterを求められる

# さらに推し進めて
# countersの最終的な数(FLAG), それぞれマス<inputと呼ぶ>のON/OFFだけ与えれば、z3に解かせて, ルール及びそれぞれ合致したときにincrementするcounterを求められる
# できそうだったが、ルールの数を３０ぐらいにしたいとき、(49inputs).combination(3)(= 210000ぐらい)のうちどのルールを使わせるかはランダムにせざるをえない？z3が内部でランダムに選んでくれる？

# さらにさらに、そのルールにおいて、与えられたマスのON,OFFの組み合わせの場合のみFLAGが出るか考える....

# ON, OFFの並びを与えなくても実装できる？ -> ランダム

# ダミー制約の生成(正しいON,OFFならば結果に影響しない)

# 普通にrubyでランダムで選んで生成するのとどっちが良い？

# 「このinputから4つONのinputが連結していれば」というルール(and/orのみならず)
# CSS(and, or, notを表現できる) == DIMACS CNF!?

# z3に与える制約
# done: input[1..n]についてのon, off
# done: それぞれcounterが目指す値(values)
# ルールにはprefixのcounterから1つ以上を使わなければならない
# すべてのinputを使わなければならない
# done: ルールに使えるinputは4つ以内 -> かんたんのため、3つに固定！w
#
# 「ルールがinput_dataに適合するとき、counterの値を足す」 -> ルールはinput_dataの内容と一致しなければならない（ルールは常に真とする)(偽になるルールは「ダミー」) && それぞれのcounterに適用されるルールはflag_valuesの数に等しい 
# これに「1つのルールで加算できるcounterは５つ」と決めると、「横(counter)方向に５マス塗る・縦(ルール)方向にflag_valueマス塗る)」ことになる…数独っぽい！
# done: ヨコ方向に５つ塗る
# done: タテ方向にflag_values個塗る
# done: すべてのinputを使う

# 「ｎ個のうちちょうど５個が真」どうやって表すんだろう？

# 出力
# 生成したルールとそれを満たした場合に加算するcountersの組み合わせ

require 'z3'
require 'pp'

class RuleGenerator
  def initialize prefix_values, flag_values, input_count, counter_names
    @prefix = prefix_values
    @flag = flag_values
    @counters = @prefix + @flag
    @counter_names = counter_names
    @input_count = input_count
    @cells = {}
    @rules = {}
    @solver = Z3::Solver.new
  end

  def generate
    # make_input_constraints
    make_rules
    make_counter_constraints

    if @solver.satisfiable?
      m = @solver.model

      @cells.each do |rule, row|
        next unless m[@rules[rule]].to_b
        print "#{rule}: ".rjust(15)
        puts row.map.with_index {|c,i| m[c].to_i == 1 ? i.to_s.rjust(2) : '  ' }.join ' '
      end

      inputs = '
      x.x.x..
      ....xxx
      .x.....
      ....xx.
      .....x.
      .x.x.x.
      x...xxx
      '.split(' ').join.chars.map { |ch| ch == 'x' }

      @cells.each do |rule, row|
        next unless m[@rules[rule]].to_b

        rule.each_with_index do |r, i|
          print inputs[r] ? "input:nth-of-type(#{r+1}):checked" : "input:nth-of-type(#{r+1}):not(:checked)"
          print " ~" if i != 2
          puts i == 2 ? " {" : ""
        end
        cs = row.map.with_index {|c, i| m[c].to_i >= 1 ? "#{@counter_names[i]} #{m[c].to_i}" : nil }.compact
        puts "  counter-increment: #{cs.shuffle.join ' '};"
        puts "}"
        puts
      end
    else
      puts 'could not solve'
    end
  end

  def make_input_constraints # すべてのinputを使う
    @inputs_used = (0...@input_count).map do |idx|
      Z3.Bool "input_used(#{idx})"
    end
    @solver.assert Z3.And(*@inputs_used)
  end

  def random_combinations
    l = (0...@input_count).to_a
    arr = l.shuffle.each_slice(3).to_a
    (3 - arr[-1].size).times { arr[-1] << (l - arr[-1]).sample }
    arr = arr.map(&:sort).uniq

    10.times do
      rules_last = arr.transpose[2] # 3つのうちの最後はカブらせない(CSSでルール同士が書き換えてしまうため)
      a = l.sample(3).sort
      arr << a if a.uniq.size == a.size && !rules_last.include?(a.last)
    end

    arr.uniq
  end

  def make_rules # ヨコ方向の制約
    # (0...@input_count).to_a.combination(3) do |(ai, bi, ci)| 
    
    # 「ruleを全部列挙したあと、すべての組み合わせかたについて、counterの制約(タテ)をつける」と組み合わせ数が爆発するので、数通りをランダムにつくって、それを全部使うことにする
    rc = random_combinations
    rc.each do |(a, b, c)|
      rule = Z3.Bool "rule(#{a}, #{b}, #{c})"
      row = add_rule a, b, c

      # すべての制約を使う
      @solver.assert rule == Z3.True
      @solver.assert Z3.Add(*row[0...@prefix.size]) >= 1
      # @solver.assert Z3.Add(*row) >= 1
      @solver.assert Z3.Add(*row) <= 10

      # @solver.assert Z3.Implies(rule, Z3.Add(*row[0...@prefix.size]) >= 1) # ruleを使うとき、@prefixから1つ以上使う
      # @solver.assert Z3.Implies(rule, Z3.And(Z3.Add(*row) >= 1, Z3.Add(*row) <= 5)) # counterを5個使う
      # @solver.assert Z3.Implies(!rule, Z3.Add(*row) == 0) # これを忘れたのでrule == Falseのときの動作は何でもアリになってしまった

      # @solver.assert Z3.Implies(rule, @inputs_used[a])
      # @solver.assert Z3.Implies(rule, @inputs_used[b])
      # @solver.assert Z3.Implies(rule, @inputs_used[c])

      @rules[[a, b, c]] = rule
    end
  end

  def add_rule a, b, c
    row = @counters.map.with_index do |_, i|
      cell = Z3.Int "cell(#{i}, (#{a},#{b},#{c}))"
      @solver.assert cell >= 0
      @solver.assert cell <= 3

      cell
    end
    
    @cells[[a, b, c]] = row
  end

  def make_counter_constraints
    @counters.each_with_index do |val, i|
      column = @cells.map { |k, row| row[i] } # 全部のruleを使うので全部のruleについて
      @solver.assert Z3.Add(*column) == val # タテ方向の制約
    end
  end
end

known_to_player = 'FLAG' # これとflagの文字列に対応するcounterを同時にルールに結びつける

# 処理スピード的に20以下に抑えたい
counter_names = "fvjygqhnlkciorptdesuxmzbwa".chars
flag = ['s0rry4C3aph0co'.chars, 46, 3].flatten # 's0rry4...'から(--var)で再現する部分を除き、'at'(46)は個別に考える
known_to_player_values = known_to_player.chars.map do |ch|
  ch.ord - 'A'.ord + 1
end
flag_values = flag.map.with_index do |ch, i|
  val = case ch
  when /[0-9]/ then ch.to_i
  when /[a-z]/ then ch.ord - 'a'.ord + 1 # counter()==0のときはlower-alphaでも'0'なので、0が含まれていたらコッチで扱うのもアリ
  when /[A-Z]/ then ch.ord - 'A'.ord + 1
  else ch
  end

  # if val > 20
  #   v = (13..20).to_a.sample
  #   puts "reduced #{ch} '#{val}' (counter #{counter_names[i+known_to_player.size]}) -> #{v}"
  #   val = v
  # end

  val
end

inputs = '
x.x.x..
....xxx
.x.....
....xx.
.....x.
.x.x.x.
x...xxx
'.split(' ').join.chars.map { |ch| ch == 'x' }

# pp (known_to_player_values + flag_values).zip(known_to_player.chars + flag)

# RuleGenerator.new(known_to_player_values, flag_values, inputs).generate
RuleGenerator.new(known_to_player_values, flag_values, 49, counter_names).generate

# fvjygqhnlkciorptde s  u xmzbwa
# FLAGs0rry4C3aph0co at 3