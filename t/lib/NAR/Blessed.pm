package NAR::Blessed;
use strict;
use warnings;

use overload '""' => sub { uc ${$_[0]} };

sub new {
    my ($class, $self) = @_;

    bless \$self, $class;
}

1;
