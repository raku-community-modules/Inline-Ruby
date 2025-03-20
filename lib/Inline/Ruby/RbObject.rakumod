
# I feel like this should be OK going IN the class...
use Inline::Ruby::RbValue;

#| Represent a Ruby object. Anything you can do method calls on.
class Inline::Ruby::RbObject {

  use NativeCall;
  constant RUBY = %?RESOURCES<libraries/rbhelper>;

  has Inline::Ruby::RbValue $.value;

  # These are inherited from Any... let's bypass that
  # so the actual Ruby gets called
  method sort(*@x)  { self.FALLBACK("sort",  |@x); }
  method first(*@x) { self.FALLBACK("first", |@x); }
  method push(*@x)  { self.FALLBACK("push",  |@x); }
  method join(*@x)  { self.FALLBACK("join",  |@x); }
  method map(*@x)   { self.FALLBACK("map",  |@x); }

  # Specific type conversions, auto-called by Raku sometimes
  method Str()     { $.value.Str() }
  method Numeric() { $.value.Numeric() }
  method Bool()    { $.value.Bool() }
  method List()    { $.value.List() }
  method Array()   { $.value.Array() }

  # Manually automatically convert deeply
  method TO-RAKU()   { $.value.TO-RAKU }

  method gist() {
    "«{ $.value }»:rb"
  }

  sub p6_rb_funcallv(
      Inline::Ruby::RbValue $obj,
      Inline::Ruby::RbValue $symbol,
      int32 $argc,
      CArray[Inline::Ruby::RbValue] $argv)
    returns Inline::Ruby::RbValue
    is native(RUBY) { * }

  # string -> symbol
  sub rb_intern(Str $val)
      returns Inline::Ruby::RbValue
      is native(RUBY) { * }

  # VALUE rb_block_call(VALUE,ID,int,const VALUE*,rb_block_call_func_t,VALUE);
  sub rb_block_call(
        Inline::Ruby::RbValue $obj,
        Inline::Ruby::RbValue $symbol,
        int32 $argc,
        CArray[Inline::Ruby::RbValue] $argv,
        &block (
          Inline::Ruby::RbValue $block_arg,
          Inline::Ruby::RbValue $block_data,
          int32 $block_argc,
          CArray[Inline::Ruby::RbValue] $block_argv
          --> Inline::Ruby::RbValue),
        int32 $data)
      returns Inline::Ruby::RbValue
      is native(RUBY) { * }

  sub mk_rb_block(&f) {
    sub (
      Inline::Ruby::RbValue $block_arg,
      Inline::Ruby::RbValue $data,
      int32 $argc,
      CArray[Inline::Ruby::RbValue] $argv
    ) returns Inline::Ruby::RbValue {
      my @args;
      for ^$argc -> $n {
        @args[$n] = Inline::Ruby::RbObject.from($argv[$n]);
      }
      Inline::Ruby::RbValue.from(&f(|@args));
    };
  }

  #| Most methods can be called directly on the Ruby VALUE
  method FALLBACK($method_name, *@args, *%args) {
    # I'd rather do this, but it doesn't work; first there is a compile-time
    # issue with CArray[Inline::Ruby::RbValue] from within itself; then after
    # that it just kinda acts funny.
    # return $.value.invoke-method($method_name, @args).to_p6;
    @args.push: |(%args.kv);

    # say "Calling $method_name with arguments: @args[]";
    my &block = @args.pop if @args[*-1] ~~ Callable;
    my $argc = @args.elems;
    my $argv = CArray[Inline::Ruby::RbValue].new;
    $argv[$_] = Inline::Ruby::RbValue.from(@args[$_]) for ^@args.elems;
    my $result;
    if &block {
      my &rb_block = mk_rb_block(&block);
      $result = rb_block_call($.value, rb_intern($method_name), $argc, $argv, &rb_block, 0);
    } else {
      $result = p6_rb_funcallv($.value, rb_intern($method_name), $argc, $argv);
    }
    Inline::Ruby::RbObject.from($result);
  }

  #| Build a new Ruby Object from a Raku value, first wrapping it
  #| as an Inline::Ruby::RbValue
  method from($p6_value) {
    if $p6_value ~~ Inline::Ruby::RbObject {
      $p6_value;
    } else {
      Inline::Ruby::RbObject.new( value => Inline::Ruby::RbValue.from($p6_value) );
    }
  }

}
