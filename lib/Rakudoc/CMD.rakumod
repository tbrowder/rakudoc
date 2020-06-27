unit module Rakudoc::CMD;

use Rakudoc;

our proto sub MAIN(|) is export(:MAIN) {

    {*}

    CATCH {
        when X::Pod::From::Cache { $*ERR.put: $_; exit 2; }
    }
}

multi sub MAIN(
    Str:D $query,
    Bool :v(:$verbose),
    #| Directories to search for documentation
    :d(:@doc) where { all($_) ~~ Str },
)
{
    my $rkd = Rakudoc.new: :$verbose, :doc-source(@doc);
    my $pod = $rkd.get-it($query);
    $rkd.show-it($pod);
}

multi sub MAIN(
    Bool :h(:$help)!
)
{
    &*USAGE(:okay);
}
