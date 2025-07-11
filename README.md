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
