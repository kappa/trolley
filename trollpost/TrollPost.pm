package TrollPost;
use Dancer;
use Template;
use Net::FriendFeed;
use Encode qw/decode/;

post '/tr/post' => sub {
    my $line = params->{line};

    content_type 'application/json';

    unless ($line) {
        status 'forbidden';
    }
    else {
        $line = decode('utf-8', $line);
        my $frf = Net::FriendFeed->new({login => set('frf_username'), remotekey => set('frf_remotekey')});

        $frf->publish_link($line, undef, undef, undef, set('frf_room'));

        return '{ c: 1 }';
    }
};

get '/tr/' => sub {
    template 'index';
};

true;
