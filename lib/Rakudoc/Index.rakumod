use JSON::Fast;

unit module Rakudoc::Index;

use Rakudoc::Utils;

constant $index-filename = 'rakudoc-index.json';

constant @index-path-candidates = Array[IO::Path](
    ("$*HOME/.raku").IO.add($index-filename),
    ("$*HOME/.perl6").IO.add($index-filename),
    $*CWD.add($index-filename)
);

constant $index-path = {
    if %*ENV<XDG_CACHE_HOME> {
        %*ENV<XDG_CACHE_HOME>.IO.add($index-filename)
    } else {
        ("$*HOME{$*SPEC.dir-sep}.raku").IO.add($index-filename)
    }
}

sub get-index-path returns IO::Path {
    my IO::Path $index-path;

    for @index-path-candidates -> $p {
        if $p.e {
            $index-path = $p;
            last;
        }
    }

    unless $index-path.defined and $index-path.e {
        fail "Unable to find rakudoc-index.json at: {@index-path-candidates.join(', ')}"
    }

    return $index-path;
}

constant INDEX is export = @index-path-candidates.first;

#| Return the intended path for the routine index file.
#| Uses $XDG_CACHE_HOME if the env variable for it is
#| set, and $HOME otherwise.
sub routine-index-path() returns IO::Path is export {
    my $xdg-cache-home = %*ENV<XDG_CACHE_HOME>;

    if defined $xdg-cache-home {
        return $xdg-cache-home.IO.add($index-filename);
    } else {
        return "{$*HOME}{$*SPEC.dir-sep}.raku".IO.add($index-filename);
    }
}
