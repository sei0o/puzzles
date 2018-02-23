require 'z3'
require 'pp'

class PuzzleSolver
  COUNTER_NAMES = 'fvjygqhnlkciorptdesu'.chars

  def initialize css_rules
    @css_rules = css_rules
    @table = []
    @solver = Z3::Solver.new 
  end

  def solve
    # setup table
    rules_count = @css_rules.size
    (0...rules_count).map do |y|
      @table[y] = COUNTER_NAMES.map do |name|
        cell = Z3.Int("cell(#{name}, #{y})")
        @solver.assert cell >= 0 # Intで持っておくと加算しやすい
        [name, cell]
      end.to_h
    end
  
    # setup inputs
    @input = (0...49).map { |i| Z3.Bool "input(#{i})" }      

    # setup counters(output)
    @output = {}
    transposed_table = Hash.new { |h, k| h[k] = [] }
    @table.each do |row|
      row.each { |name, cell| transposed_table[name] << cell }
    end
    COUNTER_NAMES.each do |ch|
      @output[ch] = Z3.Int "output(#{ch})"
      @solver.assert @output[ch] == transposed_table[ch].inject(:+)
    end
    @solver.assert @output['f'] == 'F'.ord - 'A'.ord + 1 # if output is zero, '0' will be displayed
    @solver.assert @output['v'] == 'L'.ord - 'A'.ord + 1
    @solver.assert @output['j'] == 'A'.ord - 'A'.ord + 1
    @solver.assert @output['y'] == 'G'.ord - 'A'.ord + 1
    @solver.assert @output['g'] == 's'.ord - 'a'.ord + 1
    
    # (search for another answer)
    # is_not_known_answer = '
    # x.x.x..
    # ....xxx
    # .x.....
    # ....xx.
    # .....x.
    # .x.x.x.
    # x...xxx
    # '.split(' ').join.chars.map.with_index do |ch, i|
    #   @input[i] != (ch == 'x')
    # end
    # @solver.assert Z3.Or(*is_not_known_answer)

    # setup rules
    @css_rules.each.with_index do |((i1, i2, i3), cntrs), y|
      rule_satisfied = Z3.And @input[i1[0]] == i1[1], @input[i2[0]] == i2[1], @input[i3[0]] == i3[1]
      COUNTER_NAMES.each do |name|
        if cntrs.keys.include? name
          @solver.assert Z3.Implies(rule_satisfied, @table[y][name] == cntrs[name])
          @solver.assert Z3.Implies(!rule_satisfied, @table[y][name] == 0)
        else
          @solver.assert @table[y][name] == 0
        end
      end
      # not enough, we have to constrain all cells in a row
      # cntrs.each do |name|
      #   @solver.assert Z3.Implies(rule_satisfied, @table[y][name] == 1)
      #   @solver.assert Z3.Implies(!rule_satisfied, @table[y][name] == 0)
      # end
    end

    # let the machine solve
    if @solver.satisfiable?
      m = @solver.model

      result = ''
      form = 'AAAAa0aaa0A0aaaaaaa0' # via css
      @output.each.with_index do |(name, val), i|
        puts "#{name}: #{m[val]}"
        v = m[val].to_i
        v += 10 if name == 'l'
        v += 26 if name == 's'

        case form[i]
        when /[0-9]/ then result += v.to_s
        when /[a-z]/ then result += (v + 'a'.ord - 1).chr
        when /[A-Z]/ then result += (v + 'A'.ord - 1).chr
        end
      end
      puts result

      puts "   #{COUNTER_NAMES.join}"
      @table.each_with_index do |row, i|
        x = @css_rules[i]
        last_input = x[0][2][0] + 1
        print last_input.to_s.rjust(2) + ' '
        row.map { |name, val| print m[val].to_i > 0 ? m[val].to_i : "."}
        print ' ' + x[1].flatten.join(' ')
        puts
        puts if last_input == 20
      end

      @input.each_slice(7) do |inpts|
        inpts.each { |inpt| print m[inpt].to_s =~ /input\(\d+\)/ ? "i" : (m[inpt].to_b ? "x" : ".") }
        puts
      end
    else
      puts 'could not solve'
    end
  end

end

css = File.read('rules.css').split("\n") - [""]
css_rules = css.each_slice(5).map.with_index do |x, y|
  i1 = [x[0].match(/\((\d+)\)/)[1].to_i - 1, !x[0].include?("not")] # 1-indexed!!
  i2 = [x[1].match(/\((\d+)\)/)[1].to_i - 1, !x[1].include?("not")]
  i3 = [x[2].match(/\((\d+)\)/)[1].to_i - 1, !x[2].include?("not")]
  cntrs = x[3].match(/:((.*) ([0-9]+));/)[1].split(" ").each_slice(2).to_a

  [[i1, i2, i3], cntrs.map { |c| [c[0], c[1].to_i] }.to_h]
end

PuzzleSolver.new(css_rules).solve