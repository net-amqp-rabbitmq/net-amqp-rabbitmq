requires 'ExtUtils::PkgConfig' => '1.16';
requires 'Math::Int64'         => '0';

on 'test' => sub {
  requires 'B::Debug'                        => '0';
  requires 'Devel::Cover'                    => '0';
  requires 'Devel::Cover::Report::Coveralls' => '0';
  requires 'CPAN::Meta'                      => '0';
  requires 'Math::Int64'                     => '0';
  requires 'JSON'                            => '0';
  requires 'LWP::UserAgent'                  => '0';
};

on 'develop' => sub {
  requires 'Module::CAPIMaker' => '0.01';
};
