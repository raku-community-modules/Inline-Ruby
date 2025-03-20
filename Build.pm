use Shell::Command;
use LibraryMake;

class Build {

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

  method build($dir) {
    my %vars = get-vars($dir);
    %vars<rbhelper> = $*VM.platform-library-name('rbhelper'.IO);
    %vars<rb-gcc-args> = ruby-cc-config();
    mkdir "$dir/resources" unless "$dir/resources".IO.e;
    mkdir "$dir/resources/libraries" unless "$dir/resources/libraries".IO.e;
    process-makefile($dir, %vars);
    my $goback = $*CWD;
    chdir($dir);
    shell(%vars<MAKE>);
    chdir($goback);
  }
}

# vim: ft=raku
