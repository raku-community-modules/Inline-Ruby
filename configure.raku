use LibraryMake;

#| Call out to Ruby to figure out what compile flags we should use
sub ruby-cc-config {
  my $rb-config-cmd = shell(q{
    ruby -rmkmf -e '
      print RbConfig::CONFIG["LIBS"]
      print " " + RbConfig::CONFIG["LIBRUBYARG_SHARED"]
      print " -Wl,-rpath," + RbConfig::CONFIG["archlibdir"]
      print " -L" + RbConfig::CONFIG["libdir"]
      print " -L" + RbConfig::CONFIG["archlibdir"]
      print " -I" + RbConfig::CONFIG["rubyarchhdrdir"]
      print " -I" + RbConfig::CONFIG["rubyhdrdir"]
    '
  }, :out);
  my $rb-config = $rb-config-cmd.out.slurp;

  $rb-config;
}

my %vars = get-vars('.');
%vars<rbhelper> = $*VM.platform-library-name('rbhelper'.IO);
%vars<rb-gcc-args> = ruby-cc-config();

mkdir "resources" unless "resources".IO.e;
mkdir "resources/libraries" unless "resources/libraries".IO.e;

process-makefile('.', %vars);
shell(%vars<MAKE>);
# shell('ls -laR');

# vim: ft=raku
