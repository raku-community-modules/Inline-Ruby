# TITLE

Inline::Ruby


# SYNOPSIS

```
    use Inline::Ruby;

    EVAL 'puts "Hello!"', :lang<Ruby>;
    say EVAL('Time', :lang<Ruby>).now.to_s;

    # Method calling, some simple params, cast to Str
    say ~'Time':rb.now;
    say ~'[2, 6, 8, 4]':rb.sort.slice(1,2);

    # More advanced, this is Ruby's map and each_with_index
    # This shows the :rb postfix-operator sugar instead of EVAL
    "[1,2,3,4]":rb
      .map(-> $n { +$n + 1 })
      .each_with_index: -> $n, $i { say "$n @ $i" }

    # Import and wrap ruby classes
    use csv:from<Ruby>;

    CSV.foreach: 'examples/hiya.csv', -> $row {
      say "   Raw row: {$row.gist}";
      say "Name field: $row[1]";
    }
```

# DESCRIPTION

Module for executing Ruby code and accessing Ruby libraries from Raku.

# BUILD / DEV

In theory you can get it from zef. Let me know if that's true :)

I'm running Ubuntu with ruby2.3-dev installed from apt. Then:

    ./configure.pl6  # Creates Makefile and runs make
    make test        # or prove -e 'raku -Ilib' -v

# STATUS

Master (released) branch [![Build Status](https://travis-ci.org/awwaiid/p6-Inline-Ruby.svg?branch=master)](https://travis-ci.org/awwaiid/p6-Inline-Ruby)

Develop branch [![Build Status](https://travis-ci.org/awwaiid/p6-Inline-Ruby.svg?branch=develop)](https://travis-ci.org/awwaiid/p6-Inline-Ruby)

* This only barely works!
  * Lots of missing features
  * Sometimes segfaults!
  * Only tested on my machine!
* You can currently EVAL code
* Some return types converted to Raku values:
  * TRUE
  * FALSE
  * NIL
  * FIXNUM
  * STRING
  * FLOAT
  * Objects are wrapped in an RbObject
* You can call basic methods!
* Some param types converted to Ruby values:
  * Int
  * Str

More examples:

    # Use the :rb postfix to eval a string
    # In a string context, .to_s is called in ruby
    # In Raku, .gist is called during printing, which wraps native-ruby values
    # in «...»:rb. So when you see that, you know you are looking at a wrapped
    # native Ruby object

    say '5':rb;      #=> «5»:rb

    # If you do some basic math (+,-,*,/), they will auto-convert

    say '5':rb + 2   #=> «7»:rb

    # Do it the other way around and you'll get Raku values instead

    say 2 + '5':rb   #=> 7

    # Experimental native 'use'. Tries to import things

    use csv:from<Ruby>;
    my $data = CSV.read('examples/hiya.csv')
    #=> «[["id", "name"], ["1", "andy"], ["2", "bella"], ["3", "chad"], ["4", "dua"]]»:rb

    # That gets importing wrong sometimes, so you can do it more directly
    # Here we'll slurp the file in Raku, feeding the resulting string to Ruby JSON

    BEGIN { ruby_require 'json', :import<JSON> };
    my $data = JSON.parse("examples/slide-up.json".IO.slurp);
    #=> «[{"type"=>"ClutterGroup", "id"=>"actor", ... }]»:rb

    # Now $data contains a ruby Array with nested hashes, wrapped in a Raku proxy
    # object. You can call methods and some operators, such as []. Note that ruby
    # uses [] and not {} for hash access! But we alias {} so you can still use it.

    say $data.length       #=> «2»:rb
    say $data[0]["type"]   #=> «ClutterGroup»:rb
    say $data[0]<type>     #=> «ClutterGroup»:rb

    # The value there is still a RbObject (proxy object). You can force Str or
    # Num context

    say $data[0]<children>[1]<depth>    #=> «20.0»:rb
    say ~$data[0]<children>[1]<depth>   #=> 20.0

    # Can call methods with blocks!

    "[1,2,3]":rb.map: -> $n { 1 + $n }         #=> «2, 3, 4»:rb

    use csv:from<Ruby>;
    CSV.foreach: 'customers.csv', -> $row {
      say $row[2];
    }


# NOTES/TODO - Brainstorming and such.

* Nice reference https://silverhammermba.github.io/emberb/c/
* A big trick is deciding when and how much to auto-convert between langs
  * It's nice to leave things in Ruby if they start there, so we don't have to copy it all over
  * Final values are nice to have as native Raku
  * Maybe we should only explicit-convert
* Mmm... maybe there should be two layers of .to_p6
  * One would do simple types -- strings, numbers
  * Second would do complex types -- Array, Hash
  * The simple would be called implicitly, the second explicit
* Write up Lang Integration Guide
* Separate out reusable roles

# LICENSE

The Artistic License 2.0 -- See LICENSE file.

# AUTHOR

Brock Wilcox <awwaiid@thelackthereof.org>
Some code from Stefan Seifert <nine@detonation.org>
