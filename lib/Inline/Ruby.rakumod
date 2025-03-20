
unit class Inline::Ruby;

=NAME Inline::Ruby - Execute Ruby code and libraries from Raku programs

=begin SYNOPSIS
  use Inline::Ruby;

  EVAL 'puts "Hello!"', :lang<Ruby>;

  # EVAL is pretty verbose, let's make a shorthand
  sub postfix:<:rb>($code) {
    use MONKEY-SEE-NO-EVAL;
    EVAL $code, :lang<Ruby>;
  }

  # Method calling, some simple params
  say 'Time':rb.now.to_s;
  say '[2, 6, 8, 4]':rb.sort.slice(1,2).to_s;
=end SYNOPSIS

=begin DESCRIPTION
  Module for executing Ruby code and accessing Ruby libraries from Raku.

  Simple types, such as numbers and strings, are automatically converted. For
  more complex types, such as arrays, mostly they are kept in their original
  language and converted either explicitly or as necessary.
=end DESCRIPTION

my $default_instance;

use NativeCall;
constant RUBY = %?RESOURCES<libraries/rbhelper>;

use MONKEY-SEE-NO-EVAL;

# our $wrap_in_rbobject = -> $val {
#   ::('Inline::Ruby::RbObject').new( value => $val );
# };

use Inline::Ruby::RbValue;
use Inline::Ruby::RbObject;

# my package EXPORT::DEFAULT { } # initialise the export namespace
# BEGIN for <& &bar &baz> { # iterate over the things you want to
# re-export by default
#         EXPORT::DEFAULT::{$_} = ::($_)
#       }

# Native functions

sub ruby_init()          is native(RUBY) { * }
sub ruby_init_loadpath() is native(RUBY) { * }
sub rb_gc_start()        is native(RUBY) { * }

sub ruby_script(Str $name) is native(RUBY) { * }

sub rb_eval_string_protect(Str $code, int32 $state is rw)
    returns Inline::Ruby::RbValue
    is native(RUBY) { * }

sub ruby_exec_node(Pointer $node)
    is native(RUBY) { * }

sub ruby_options(int32 $argc, CArray[Str] $argv)
    returns Pointer
    is native(RUBY) { * }

method BUILD() {
#   say "Ruby lib: " ~ RUBY;
  $default_instance //= self;
  ruby_init();

  ruby_init_loadpath();
  ruby_script('rakudo');

  rb_gc_start(); # I have no idea if this works

  # TODO: What else do we need to do?
  # rb_funcall(rb_stdout, rb_intern("sync="), 1, 1);

  # Setting options to -enil lets us start ruby
  # without complaint about not having some stuff.
  # my $opts = CArray[Str].new;
  # $opts[0] = "";
  # $opts[1] = "-enil";
  # my $options = ruby_options(2, $opts);
  # ruby_exec_node($options);

}

# Singleton instances for common uses
method default_instance {
  # say "loading default...";
  $default_instance //= self.new;
}

method run($str) {
  my int32 $state = 0;
  my $result = rb_eval_string_protect($str, $state);
  if $state {
    my $msg = EVAL('$!.to_s', :lang<Ruby>) || "ERROR";
    die "EVAL-RUBY EXCEPTION: $msg";
  }
  $result;
}

multi sub EVAL(
  Cool $code,
  Str :$lang where { ($lang // '') eq 'Ruby' },
  PseudoStash :$context
) is export {
  state $rb //= Inline::Ruby.default_instance;
  Inline::Ruby::RbObject.from( $rb.run($code) );
}

role RubyPackage[Str $module] {
    # has $!parent;

    method new(*@args, *%args) {
      self.FALLBACK('new');
    }

    method FALLBACK($name, *@args) {
      # say "Calling $module method $name args @args[]";
      EVAL("$module", :lang<Ruby>)."$name"(|@args);
    }
}

sub ruby_import ($module) is export {
  # Skip already existing classes
  if ::("$module") !~~ Failure {
    $*ERR.say: "Raku→RB WARNING: NOT creating proxy for class «$module»:rb (class already defined)";
    next;
  }

  # say "Creating proxy for class «$module»:rb";
  my $class := Metamodel::ClassHOW.new_type( name => $module );
  $class.^add_role(RubyPackage[$module]);

  $class.^compose;

  # register the new class by its name
  my @parts = $module.split('::');
  my $inner = @parts.pop;
  my $ns := ::GLOBAL.WHO;
  for @parts {
      $ns{$_} := Metamodel::PackageHOW.new_type(name => $_) unless $ns{$_}:exists;
      $ns := $ns{$_}.WHO;
  }
  my @existing = $ns{$inner}.WHO.pairs;
  $ns{$inner} := $class;
  $class.WHO{$_.key} := $_.value for @existing;
}

our sub ruby_require ($name, :$import is copy) is export {
  # say "Requiring ruby module $name";
  EVAL(q:to/RUBYCODE/, :lang<Ruby>);
    $created_class = []
    class Object
      def self.inherited(new_class)
        # puts "Created: #{new_class}"
        $created_class << new_class
      end
    end
  RUBYCODE

  EVAL "require '$name'", :lang<Ruby>;

  # TODO: Really we should back up and restore whatever was there
  EVAL(q:to/RUBYCODE/, :lang<Ruby>);
    class Object
      def self.inherited(new_class)
      end
    end
  RUBYCODE

  $import //= EVAL('$created_class', :lang<Ruby>).List.map: { .Str };

  for |$import -> $module {
    ruby_import($module);
  }

}

class ::CompUnit::Repository::Ruby does CompUnit::Repository {

  my $prev-repo = $*REPO.repo-chain[*-1];
  $prev-repo.next-repo = CompUnit::Repository::Ruby.new;

  method id() {
      'ruby'
  }

  method need(CompUnit::DependencySpecification $spec, CompUnit::PrecompilationRepository $precomp) {
      # say "need $spec.short-name() from $spec.from()";
      if $spec.from eq 'Ruby' {
        # say "Loading a ruby lib... $spec.raku()";
        # say "Loading a ruby lib...";
        Inline::Ruby::ruby_require($spec.short-name);

        return CompUnit.new(
          short-name => $spec.short-name,
          handle     => CompUnit::Handle.from-unit(::($spec.short-name).WHO),
          repo       => self,
          repo-id    => $spec.short-name,
          from       => $spec.from,
        );

      } else {
        $prev-repo.next-repo = CompUnit::Repository;
        LEAVE {
            $prev-repo.next-repo = self;
        }
        $*REPO.need($spec)
      }
  }

  method loaded() {
      []
  }

  method path-spec() {
      'ruby#'
  }
}

# TODO: Get all of these multi-subs to live in RbObject and re-export

multi sub infix:<+>(Inline::Ruby::RbObject $left-obj, Any $right-obj) is export {
  $left-obj."+"($right-obj);
}

multi sub infix:<->(Inline::Ruby::RbObject $left-obj, Any $right-obj) is export {
  $left-obj."-"($right-obj);
}

multi sub infix:<*>(Inline::Ruby::RbObject $left-obj, Any $right-obj) is export {
  $left-obj."*"($right-obj);
}

multi sub infix:</>(Inline::Ruby::RbObject $left-obj, Any $right-obj) is export {
  $left-obj."/"($right-obj);
}

multi sub infix:<%>(Inline::Ruby::RbObject $left-obj, Any $right-obj) is export {
  $left-obj."%"($right-obj);
}

multi sub postcircumfix:<[ ]>(Inline::Ruby::RbObject $left-obj, Any $right-obj) is export {
  $left-obj."[]"($right-obj);
}

# Ruby doesn't really differentiate between [] and {}, so we'll sugar it
multi sub postcircumfix:<{ }>(Inline::Ruby::RbObject $left-obj, Any $right-obj) is export {
  $left-obj."[]"($right-obj);
}

# Sugary delicousness for running inline ruby code
sub postfix:<:rb>($code) is export {
  use MONKEY-SEE-NO-EVAL;
  EVAL $code, :lang<Ruby>;
}


=AUTHOR Brock Wilcox <awwaiid@thelackthereof.org>

