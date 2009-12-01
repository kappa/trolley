# This is a PSGI application file for Apache+Plack support
use CGI::PSGI;
use lib '/home/kappa/work/TrollPost';
use TrollPost;

use Dancer::Config 'setting';
setting apphandler  => 'PSGI';
setting environment => 'production';
Dancer::Config->load;

my $handler = sub {
    my $env = shift;
    Dancer->dance(CGI::PSGI->new($env));
};
