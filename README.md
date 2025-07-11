## Overview 
This repository provides composable building blocks for wrangling GitHub Actions to
test every commit in a pull request and provide a reasonable UI representing the results.

### `get-pr-shas`
Given a pull request event, get a list of every commit in the pull request and
the fetch-depth required to get a clone that contains every commit.

#### Outputs
- *fetch-depth*: depth required to fetch every commit in the pull request.
  This can be passed to actions/checkout.
- *shas*: JSON array of the abbreviated SHA of every commit in the pull
  request.  This can be used to build a test matrix.  For instance:

  ```yaml
  test-commits:
    needs: get-pr-shas
    strategy:
      fail-fast: false
      matrix:
        sha: ${{ fromJson(needs.gather-pr-shas.outputs.shas) }}
      ...
  ```

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
`get-pr-shas` and `test-commit` can be combined to run multiple tests on every
commit in a pull request.

```yaml
on: pull_request
jobs:
  gather-pr-commits:
    runs-on: ubuntu-latest
    outputs:
      shas: ${{ steps.get-shas.outputs.shas }}
      fetch-depth: ${{ steps.get-shas.outputs.fetch-depth }}
    steps:
      - uses: jsbronder/actions/get-pr-shas@v1
        id: get-shas

  test-commits:
    runs-on: ubuntu-latest
    needs: gather-pr-commits
    permissions:
      contents: read
      statuses: write
    strategy:
      fail-fast: false
      matrix:
        sha: ${{ fromJson(needs.gather-pr-commits.outputs.shas) }}
        command: ["make test", "make lint"]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: ${{ needs.gather-pr-commits.outputs.fetch-depth }}
      - name: ${{ matrix.command }}/${{ matrix.sha }}
        uses: jsbronder/actions/test-commit@v1
        with:
          sha: ${{ matrix.sha }}
          context: test/${{ matrix.command }}
          command: ${{ matrix.command }}
```

