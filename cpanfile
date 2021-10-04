requires 'ExtUtils::PkgConfig' => '1.16';
requires 'Module::CAPIMaker'   => '0.01';
requires 'Math::Int64'         => '0';

on 'test' => sub {
  requires 'Devel::Cover'                    => '1.24';
  requires 'Devel::Cover::Report::Coveralls' => '0';
  requires 'CPAN::Meta'                      => '0';
  requires 'Math::Int64'                     => '0';
  requires 'JSON'                            => '0';
  requires 'LWP::UserAgent'                  => '0';
};
