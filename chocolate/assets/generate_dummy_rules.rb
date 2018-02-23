used_last = [
34,
44,
45,
35,
32,
23,
37,
49,
26,
41,
19,
25,
47,
48,
46,
40,
24,
38,
21,
15,
20,
1,
2
] # 1,2はそもそも最後に置けない

flag_counters = 'fvjy'.chars
counters = 'gqhnlkciorptdesu'.chars

inputs = '
x.x.x..
....xxx
.x.....
....xx.
.....x.
.x.x.x.
x...xxx
'.split(' ').join.chars.map { |ch| ch == 'x' }

# until we use all cells 
while ((1..49).to_a - used_last).any?
  last = ((1..49).to_a - used_last).sample
  used_last << last
  n = (1...last).to_a.shuffle[0..1].sort

  cs = flag_counters.sample([1,2].sample) + counters.sample([1, 1, 2, 2, 3].sample)
  counter_and_nums = cs.uniq.map do |name|
    "#{name} #{(1..3).to_a.sample}"
  end

  # 1番目の条件は常に成り立たないようにする
  puts <<-EOS
  input:nth-of-type(#{n[0]})#{inputs[n[0] - 1] ? ':not(:checked)' : ':checked'} ~
  input:nth-of-type(#{n[1]})#{[':not(:checked)',':checked'].sample} ~
  input:nth-of-type(#{last})#{[':not(:checked)',':checked'].sample} {
    counter-increment: #{counter_and_nums.shuffle.join ' '};
  }
  
  EOS
end

# 複数解は手で消していこうな