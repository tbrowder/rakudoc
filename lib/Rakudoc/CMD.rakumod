use Rakudoc;
use Rakudoc::Utils;
use Rakudoc::Index;

use Documentable;

use JSON::Fast;

package Rakudoc::CMD {
    my $PROGRAM-NAME = "rakudoc";

    sub USAGE() is export {
        say q:to/END/;
            rakudoc, a tool for reading Raku documentation

            Usage:
                rakudoc    [-n]           FILE
                rakudoc    [-n] [-d=DIR]  TYPE | FEATURE | MODULE
                rakudoc    [-n] [-d=DIR]  TYPE.ROUTINE
                rakudoc -r [-n] [-d=DIR]  ROUTINE
                rakudoc -b [-d=DIR]
                rakudoc -h

            Where:
                FILE        File containing POD documentation
                TYPE        Type or class
                MODULE      Module in Raku's module search path
                FEATURE     Raku langauge feature
                ROUTINE     Routine or method associated with a type

            Options:
                [-d | --dir]                Specify a doc directory
                [-n | --nopager]            Deactivate pager usage for output
                [-r | --routine ROUTINE]    Search index for ROUTINE
                [-h | --help]               Display this help
                [-b | --build]              Build the search index

            Examples:
                rakudoc ~/my-pod-file.rakumod       FILE
                rakudoc IO::Spec                    TYPE
                rakudoc JSON::Fast                  MODULE
                rakudoc exceptions                  FEATURE
                rakudoc Map.new                     TYPE.ROUTINE
                rakudoc -r starts-with              ROUTINE

            See also:
                rakudoc intro
                rakudoc pod
                https://docs.raku.org/
            END
    }

    our proto MAIN(|) is export {

        {*}

        CATCH {
            when X::Rakudoc {
                .put;
                exit 2;
            }
        }

        # Meaningless except to t/01-cmd.t
        True;
    }

    multi MAIN(Bool :h(:$help)!, |_) {
        USAGE();

        exit;
    }

    multi MAIN(Str $pod-file where *.IO.e, Bool :n(:$nopager)) {
        say load-pod-to-txt($pod-file.IO);
    }

    multi MAIN(Str $query, Bool :r(:$routine), Str :d(:$dir), Bool :n(:$nopager)) {
        my $use-pager = True;
        $use-pager = False if $nopager;

        my @doc-dirs;

        fail "$dir does not exist, or is not a directory"
            if defined $dir and not $dir.IO.d;

        # If directory is provided via `-d`, only look there
        # TODO: There should be a way to detect whether the provided
        # directory is the regular standard documentation, or an arbitrary
        # folder containing .rakudoc files.
        my @dirs = $dir ?? $dir !! get-doc-locations;
        my @subdirs = $routine ?? 'Type' !! Kind.enums.keys;

        @doc-dirs = cross :with({$^a.add($^b)}), @dirs, @subdirs;

        my $search-results;
        if $routine {
            my $index-path = index-path();

            $index-path.s or die X::Rakudoc.new:
                :message<No index file found, build index first>;

            # Map the Str result(s) from index into Documentables
            $search-results = map { |type-routine-query($_) },
                                routine-search($query, $index-path);
        }
        else {
            if $query.contains('.') {
                $search-results = type-routine-query($query);
            } else {
                $search-results = single-query($query);
            }
        }

        show-search-results($search-results, :$use-pager);

        return True;  # Meaningless except to t/01-cmd.t

        sub single-query($query) {
            my IO::Path @pod-paths;
            my Documentable @documentables;

            for @doc-dirs -> $dir {
                @pod-paths.append: find-type-files($query, $dir);
            }

            @documentables = process-type-pod-files(@pod-paths);
            type-search($query, @documentables);
        }

        sub type-routine-query($query) {
            # e.g. split `Map.new` into `Map` and `new`
            my @squery = $query.split('.');

            if not @squery.elems == 2 {
                fail 'Malformed input, example: Map.elems';
            } else {
                my IO::Path @pod-paths;
                my Documentable @documentables;

                for @doc-dirs -> $dir {
                    @pod-paths.append: find-type-files(@squery[0], $dir);
                }

                @documentables = process-type-pod-files(@pod-paths);
                type-search(@squery[0],
                                              :routine(@squery[1]),
                                              @documentables);
            }
        }
    }

    multi MAIN(Bool :b(:$build)!, Str :d(:$dir)) {
        my $index-path = index-path();

        fail "$dir does not exist, or is not a directory"
            if $dir.defined and not $dir.?IO.d;

        put "Writing index to {$index-path}...";
        given $index-path.dirname.IO { .d or .mkdir }
        write-index-file($index-path, $dir.?IO // |get-doc-locations);
        put "Done.";
    }
}
