use strict;
use warnings;
use Test::Requires qw(DBD::mysql Test::mysqld);
use Test::More;
use Test::mysqld;
use t::Util;
use DBIx::QueryLog ();
use DBI;

DBIx::QueryLog->explain(1);

my $mysqld = t::Util->setup_mysqld
    or plan skip_all => $Test::mysqld::errstr || 'failed setup_mysqld';

my $dbh = DBI->connect(
    $mysqld->dsn(dbname => 'mysql'), '', '',
    {
        AutoCommit => 1,
        RaiseError => 1,
    },
) or die $DBI::errstr;

my $regex = do {
    my $sth = $dbh->prepare('EXPLAIN SELECT * FROM user WHERE User = ?');
    $sth->bind_param(1, 'root');
    $sth->execute;

    join '\s+\|\s+', @{$sth->{NAME}};
};

DBIx::QueryLog->begin;

TEST:
subtest 'do' => sub {
    my $res = capture {
        $dbh->do('SELECT * FROM user WHERE User = ?', undef, 'root');
    };

    like $res, qr/$regex/;
};

subtest 'execute' => sub {
    my $res = capture {
        my $sth = $dbh->prepare('SELECT * FROM user WHERE User = ?');
        $sth->bind_param(1, 'root');
        $sth->execute;
    };

    like $res, qr/$regex/;
};

for my $method (qw/selectrow_array selectrow_arrayref selectall_arrayref/) {
    subtest $method => sub {
        my $res = capture {
            $dbh->$method(
                'SELECT * FROM user WHERE User = ?', undef, 'root'
            );
        };

        like $res, qr/$regex/;
    };
}

DBIx::QueryLog->explain(0);

unless ($ENV{DBIX_QUERYLOG_EXPLAIN}) {
    # enabled skip_bind
    $ENV{DBIX_QUERYLOG_EXPLAIN} = 1;
    goto TEST;
}

done_testing;
