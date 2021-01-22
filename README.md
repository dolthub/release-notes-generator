# GitHub release notes generator

This tool generates release notes for a GitHub repository consisting
of a summary of merged PRs and closed issues since the last
release. With a release tag argument, it will generate release notes
for an existing release so that you can backfill this information for
previous releases.

Example:

```bash
./gen_release_notes.pl \
    -d dolthub/go-mysql-server \
    -d dolthub/vitess \
    dolthub/dolt v0.22.9
```

This tells the tool to generate release notes for
[dolthub/dolt](https://github.com/dolthub/dolt) for the release tagged
`v0.22.9`, and to include any changes to the dependencies
[dolthub/go-mysql-server](https://github.com/dolthub/go-mysql-server)
and [dolthub/vitess](https://github.com/dolthub/vitess) that were
built into this release. The end of this README contains an example of
the output it produces.

# Usage

The tool will clone the repo given unless a repository with the same
name exists in the working directory. Therefore, if you intend to
genereate release notes for a project you already have checked out
locally, it's recommended that you clone this repo alongside the one
you want to generate release notes for. E.g.:

```bash
% find . -maxdepth 1
.
./dolt
./release-notes-generator
./my-other-project
% ./release-notes-generator/gen_release_notes.pl \
    -d dolthub/go-mysql-server \ 
    dolthub/dolt v0.22.9
```

Since `dolt` exists in the current working directory, the tool will
assume that's the repository you're generating release notes for. It
should be up to date with the GitHub remote.

# Requirements

* Perl 5.14 or higher (tested only with 5.26 but should work with 14 or higher)
* [DateTime::Format::ISO8601](https://metacpan.org/pod/DateTime::Format::ISO8601)
* [JSON::Parse](https://metacpan.org/pod/JSON::Parse)
* `git`, `curl`

# Limitations

Dependencies are only supported for golang projects with a go.mod
file. And dependency parsing in general is very limited.

# GitHub Auth

GitHub limits anonymous RPCs to 60 per hour, and this could change in
the future. If you hit the rate limit, you will need to provide a
personal API token. Details and instructions for obtaining a token can
be found in the file comment in the script.

# Example output

The tool produces markdown output like the below that you can paste
directly into your GitHub release.

# Merged PRs

* [1170](https://github.com/dolthub/dolt/pull/1170): Updating to latest go-mysql-server
* [1169](https://github.com/dolthub/dolt/pull/1169): go/libraries/doltcore/sqle: Keyless tables don't have PK index -- fix describe panic
* [1168](https://github.com/dolthub/dolt/pull/1168): /.github/{scripts,workflows}: fix, pod to job, handle pod errors
* [1167](https://github.com/dolthub/dolt/pull/1167): C# test for alternate MySQL connector library, upgraded existing to u…
  …se dotnet 5 (up from 3)
* [1165](https://github.com/dolthub/dolt/pull/1165): /.github/workflows/ci-performance-benchmarks.yaml: fix id
* [1163](https://github.com/dolthub/dolt/pull/1163): Db/ci performance
* [1162](https://github.com/dolthub/dolt/pull/1162): unrolled decode varint decode loop
  30% faster on the benchmark in this PR.
  BenchmarkUnrolledDecodeUVarint/binary.UVarint-8         	1000000000	         0.0372 ns/op
  BenchmarkUnrolledDecodeUVarint/unrolled-8               	1000000000	         0.0258 ns/op
* [1147](https://github.com/dolthub/dolt/pull/1147): Fixed indentiation in YAML syntax for Discord notifications
* [1143](https://github.com/dolthub/dolt/pull/1143): First cut of Discrod notifications
  This implements the following policy:
  - notify on cancellation or failure of any job
  - notify on release, including success
  Currently release notifications are broken by a shortcoming in GitHub Actions, namely that one workflow cannot kick of another when using `GITHUB_TOKEN`. We will devise a workaround.
* [256](https://github.com/dolthub/go-mysql-server/pull/256): added describe queries for keyless tables
* [255](https://github.com/dolthub/go-mysql-server/pull/255): This function implement an Naryfunction type.
  Allows you to define sqle functions that have multiple children.
* [254](https://github.com/dolthub/go-mysql-server/pull/254): Fixed UNHEX/HEX roundtrip
  Simple fix but I ended up completely reevaluating our binary type implementation. Fixed a bug found in the `cast` package we were using to convert strings, and also changed `UNHEX` to return the proper SQL type.
* [252](https://github.com/dolthub/go-mysql-server/pull/252): Added hash functions
* [249](https://github.com/dolthub/go-mysql-server/pull/249): Alias bug fixes
  Fixes a number of buggy behaviors involving column indexes and table name resolution.
* [248](https://github.com/dolthub/go-mysql-server/pull/248): additional tests
  add a table with multiple keys
  an index that has a subset of those keys in a different order
  a couple queries

# Closed Issues

* [1161](https://github.com/dolthub/dolt/issues/1161): Primary keyless tables seem to break DESCRIBE
* [1153](https://github.com/dolthub/dolt/issues/1153): p.StopWithErr(err) is hanging on large imports
