package ListDependencies;
use strict;

unshift @INC, sub {
        local $_ = $_[1];
        return unless /[[:upper:]]/;
        s/\.pm$//i;
        s/[\/:]/::/g;
	if($_ =~ m/^\w*::\w*$/i) { print STDOUT $_, $/; }
};

1;

__END__
