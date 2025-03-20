use lib "lib";
use Inline::Ruby;

# Plain EVAL
EVAL 'puts "Hello!"', :lang<Ruby>;

say "Ruby-map and Ruby-each_with_index";
"[1,2,3,4]":rb
  .map(-> $n { +$n + 1 })
  .each_with_index: -> $n, $i { say "$n @ $i" }

use csv:from<Ruby>;

say "Iterating over a CSV file";
CSV.foreach: 'examples/hiya.csv', -> $row {
  say "   Raw row: {$row.gist}";
  say "Name field: $row[1]";
}

# say "Now with headers";
# CSV.foreach('examples/hiya.csv', :headers => True, -> $row {
#   say $row;
#   say "Name: $row[1]";
# });


# Explore some representations
#
# BEGIN {
#   q{
#     class Foo
#       def saysym(*args)
#         args.each do |s|
#           puts "Got: #{s.inspect} class #{s.class.to_s}"
#         end
#       end
#     end
#   }:rb;

#   ruby_import('Foo');
# }

# Foo.new.saysym(:bye, False, :fishies);

