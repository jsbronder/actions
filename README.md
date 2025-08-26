## Overview 
This repository provides composable building blocks for wrangling GitHub Actions to
test every commit in a pull request and provide a reasonable UI representing the results.

### `expand-matrix`
Given a pull request event and a test matrix, expand the matrix by adding the
short and full SHA of every commit in the pull request to each item in the
matrix.

#### Inputs
- *matrix*: JSON test matrix to be expanded.

#### Outputs
- *matrix*: Original JSON matrix expanded with the `sha` and `short_sha` of
  every commit in series added to each object in the array.

### `test-commit`
Runs a test on a given commit and uses GitHub's commit statuses as a cache so
that tests are not run again on successive jobs.  This composite action needs
`contents: read` and `statuses: write` permission.

#### Inputs
- *sha*: commit SHA to test.
- *context*: GitHub status context.  If running as part of a test matrix, this
  needs to be unique for every test in the matrix.
- *command*: Shell command to run as the test.

## Testing Every Commit in a Pull Request
`expand-matrix` and `test-commit` can be combined to run multiple tests on every
commit in a pull request.

```yaml
name: Test Every Commit
on: pull_request
jobs:
  expand-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.expand-matrix.outputs.shas }}
    steps:
      - uses: jsbronder/actions/expand-matrix@v2
        id: expand-matrix
        with: |
            [
                {"name": "test-1", "command": "make test-1"},
                {"name": "test-2", "command": "./run-test-2"}
            ]

  test-commits:
    runs-on: ubuntu-latest
    needs: expand-matrix
    permissions:
      contents: read
      statuses: read
    strategy:
      fail-fast: false
      matrix:
        sha: ${{ fromJson(needs.expand-matrix.outputs.matrix) }}
    name: ${{ matrix.name }}/${{ matrix.short_sha }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ matrix.sha }}
      - uses: jsbronder/actions/test-commit@v2
        with:
          sha: ${{ matrix.short_sha }}
          context: test/${{ matrix.name }}/${{ matrix.short_sha }}
          command: ${{ matrix.command }}
```

`set-commit-statuses` can then be used to set the commit status for each commit
tested by `test-commit` by adding it as a workflow that is run after the *Test
Every Commit* workflow:  Note that the pairing of `on: pull_request` and `on:
workflow_run`, while cumbersome, is intentional in order to prevent leaking
write permissions to forked repositories.  You can read more on the GitHub Blog
about ["pwn
requests"](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/)

```
name: Set Commit Statuses

on:
  workflow_run:
    workflows: ["Test Every Commit"]
    types:
      - completed

jobs:
  set-commit-statuses:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
      statuses: write
    steps:
      - uses: jsbronder/actions/set-commit-statuses@v1
```

### Paper Cuts
GitHub actions, like a lot of CI systems, wasn't built to treat commits as
individual entities.  As you can see above, it's not exactly straight-forward
to get every commit in a series tested.  However, some shops do place a premium
on having a clear history that developers can read through, both while
reviewing the proposed changes and later when on an archaeological mission.
Furthermore, ensuring the code builds and tests pass drastically reduces the
friction to running git-bisect.  A bunch of "all: fix lints" commits don't help
anyone.

That said, this solution isn't perfect and there poor UI/UX situations that
should be noted.

- Commit Statuses cannot be removed or updated.  So if a PR is run against a
  mainline that later changes how the `context` is constructed or removes a
  test `command`, then the tested commits will never get a chance to recover
  from failed.  The easiest thing to do in this case is rebase the PR so each
  SHA in the series changes.
  Similarly if commits are added to a failing PR, the previous HEAD of that PR
  will be stuck with all of the old failing checks.  In this case, rebase and
  reword the first commit.  This will change the SHA of the first commit, and
  hence, every commit that follows it, granting them a clean status.
- We cannot link directly to the job that failed in a matrix.  Hopefully this
  will be resolved, https://github.com/orgs/community/discussions/8945
- GitHub actions create their own statuses on the `HEAD` commit of every PR.
  When using a job matrix, this means the `HEAD` commit is going to get linked
  to the jobs that ran for every commit in the series.  There is no apparent
  way to remove these.
  Likely, one would not want to remove them anyways, as the statuses for each
  commit in the series otherwise not accessible in the dropdown for checks
  run on the pull request.
- A pull request will run the set of tests listed for `test-commits` found in
  the `HEAD` of the pull request.  So care should be taken to review any
  changes to the workflow.

