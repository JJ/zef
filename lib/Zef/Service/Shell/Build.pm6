use Zef;

class Zef::Service::Shell::Build does Builder does Messenger {
    method build-matcher($path) { $path.IO.child("Build.pm").e }

    method probe { True }

    # todo: write a real hooking implementation to CU::R::I
    # this is a giant ball of shit btw, but required for
    # all the existing distributions using Build.pm
    method build($path, :@includes) {
        die "path does not exist: {$path}" unless $path.IO.e;

        # make sure to use -Ilib instead of -I. or else Linenoise's Build.pm will trigger a strange precomp error
        my $build-file = $path.IO.child("Build.pm").absolute;
        my $cmd        = "require '$build-file'; ::('Build').new.build('$path.IO.absolute()') ?? exit(0) !! exit(1);";
        my @exec       = |($*EXECUTABLE, '-Ilib', |@includes.grep(*.defined).map({ "-I{$_}" }), '-e', "$cmd");

        $.stdout.emit("Command: {@exec.join(' ')}");

        my $ENV := %*ENV;
        my $passed;
        react {
            my $proc = zrun-async(@exec);
            whenever $proc.stdout.lines { $.stdout.emit($_) }
            whenever $proc.stderr.lines { $.stderr.emit($_) }
            whenever $proc.start(:$ENV, :cwd($path)) { $passed = $_.so }
        }
        return $passed;
    }
}
