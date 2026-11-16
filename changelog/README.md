# Changelog fragments

A pull request puts its lines for [CHANGELOG.md](../CHANGELOG.md) here,
in a file of its own, instead of adding them to CHANGELOG.md. Each pull
request then changes a file no other one touches, so a merge to main
leaves the other open pull requests without a conflict, and without the
merge of main and the full builds that settling one used to cost.

Name the file after the pull request's number (`changelog/168.md`).
Before it has one, the name of its branch will do, with any `/` made a
`-` (a folder in `changelog/` fails the check), but only when no earlier
pull request came from a branch of that name: a fragment that takes the
name of one main still has writes over that one's lines, as #508's did
to #502's. Write CHANGELOG.md's own lines, one per change, each ending
with the pull request's number (two as `(#511, #513)`):

```
- Tools palette: long names shrink or wrap instead of being cut off (#168)
```

The pull request that sets a release's version folds every fragment into
the "Unreleased" section of CHANGELOG.md, in the order they were merged,
and deletes them (`python3 tools/ci/changelog.py fold`; see "Making a
release" in [BUILDING.md](../BUILDING.md)). CI checks that every fragment
is made of such lines, and that no pull request loses its lines: one with
a line in a fragment on main must still have one, in a fragment or in
CHANGELOG.md (`python3 tools/ci/changelog.py check --base HEAD^1`, where
`HEAD^1` is main as the pull request finds it; without `--base` only the
form of the lines is checked). A line may be reworded. A change to this
folder alone starts no build.
