# ZAgents Spec Kit tests — GitHub Action

This action runs the spec tests of a ZAgents project against the code of **your** checkout. It then reports pass, fail or none for every test back to ZAgents, where the badges on the spec map update live. It also writes a job summary.

```yaml
- uses: ZurabDev/zagents-releases/actions/spec-kit-test@v1
  with:
    token: ${{ secrets.ZAGENTS_TOKEN }}
    project: Pricing 2.0
    gate: pr
```

Under the hood the action installs the `zagents` CLI and runs `zagents spec test run`. The same runner works outside GitHub as the bash script `scripts/spec-kit-test.sh` (see "GitLab CI / Jenkins" below).

## Gates

| Test `gate` | Runs with `gate:` input | Blocks |
|---|---|---|
| `deploy` (critical, keep few) | `deploy`, `pr`, `nightly` | deploys and PRs |
| `pr` | `pr`, `nightly` | PRs |
| `nightly` | `nightly` | the nightly job |
| `manual` | `manual` only | nothing unless asked |

The step fails (exit 1) when a test of the `fail-on` gate fails. The default for `fail-on` comes from `gate`: `deploy` with `deploy`, `pr` with `pr`, and `any` otherwise.

## Inputs

| Input | Default | |
|---|---|---|
| `token` | required | Workspace API token. Store it as the `ZAGENTS_TOKEN` secret. |
| `gate` | `pr` | `deploy`, `pr`, `nightly`, `manual` or `all` |
| `project`, `component`, `spec`, `issue` | | selectors, combined with AND |
| `tags` | | comma or newline separated; a test matches if it has any of them |
| `fail-on` | from `gate` | `deploy`, `pr` or `any` |
| `parallel` | `1` | number of batches run at the same time |
| `working-directory` | `.` | checkout root |
| `junit-dir` | | keep JUnit files here, e.g. for upload as artifacts |
| `server-url` | `https://zagents.cnt.me` | |
| `workspace-id` | | set it when the token is not bound to one workspace |
| `cli-version` | latest | e.g. `0.7.0-mz.1` |
| `upload-junit` | `false` | `true` uploads the JUnit files as a workflow artifact (`junit-dir`, or a temporary directory) |
| `artifact-name` | `zagents-spec-tests-junit` | name of that artifact |
| `args` | | extra `zagents spec test run` flags, shell-quoted (`--include-unapproved --tag 'smoke test'`); an unbalanced quote fails the step |

The outputs are `exit-code`, `result-file` (the JSON written by `--output json`), `passed`, `failed` and `junit-dir`. Every failed test is annotated on the run page with its path and reason.

Useful `args`: `--changed-since <base-sha>` runs only the tests a PR touches (plus every deploy test; check out with `fetch-depth: 0`), `--deployment production` records the deploy gate outcome on the specs. `scripts/spec-kit-verify-protection.sh --repo OWNER/REPO --check <job>` (published next to `spec-kit-test.sh`) tells you whether the job is a required status check.

The CLI is installed from the release and is never run unverified: a missing `checksums.txt`, a missing entry or a mismatch stops the step (exit 2).

## PR workflow

```yaml
name: Spec tests (PR)
on: pull_request
jobs:
  spec-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5      # whatever your tests need
        with: { go-version-file: go.mod }
      - uses: ZurabDev/zagents-releases/actions/spec-kit-test@v1
        with:
          token: ${{ secrets.ZAGENTS_TOKEN }}
          project: Pricing 2.0
          gate: pr
          parallel: 4
```

## Deploy workflow (a required step before rollout)

```yaml
jobs:
  spec-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ZurabDev/zagents-releases/actions/spec-kit-test@v1
        with:
          token: ${{ secrets.ZAGENTS_TOKEN }}
          project: Pricing 2.0
          gate: deploy
          args: --require-tests
  deploy:
    needs: spec-gate          # no green deploy gate → no rollout
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

## Nightly workflow

```yaml
on:
  schedule: [{ cron: "0 3 * * *" }]
jobs:
  nightly:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ZurabDev/zagents-releases/actions/spec-kit-test@v1
        with:
          token: ${{ secrets.ZAGENTS_TOKEN }}
          project: Pricing 2.0
          gate: nightly
          fail-on: any
          junit-dir: out/junit
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: spec-junit, path: out/junit }
```

## GitLab CI / Jenkins / any bash

```yaml
# .gitlab-ci.yml
spec-tests:
  script:
    - curl -fsSL https://raw.githubusercontent.com/ZurabDev/zagents-releases/main/scripts/spec-kit-test.sh
      | bash -s -- --gate deploy --project "Pricing 2.0"
  variables:
    ZAGENTS_TOKEN: $ZAGENTS_TOKEN   # masked CI/CD variable
```

```groovy
// Jenkinsfile
withCredentials([string(credentialsId: 'zagents-token', variable: 'ZAGENTS_TOKEN')]) {
  sh 'curl -fsSL https://raw.githubusercontent.com/ZurabDev/zagents-releases/main/scripts/spec-kit-test.sh | bash -s -- --gate pr --project "Pricing 2.0"'
}
```

The script reads `ZAGENTS_TOKEN` (required) and `ZAGENTS_SERVER_URL` (default `https://zagents.cnt.me`). The optional variables are `ZAGENTS_WORKSPACE_ID`, `ZAGENTS_CLI_VERSION` and `ZAGENTS_BIN_DIR`. Every other argument is passed to `zagents spec test run`. Run `bash spec-kit-test.sh --help` for the full list.

## How tests are run

The plan comes from ZAgents (`zagents spec test plan --project … --gate …` shows it). Each test runs with the first command that is set, in this order:

1. its own `run_command`
2. its component's `test_command`
3. its domain's `test_command`
4. a built-in preset chosen by file path:
   - `go test` for `*_test.go`
   - vitest for `*.test.ts`
   - playwright for `e2e/**`
   - pytest for `test_*.py`

Results are read from JUnit XML or `go test -json`. A test whose file is missing in the checkout, or that the report does not mention (a mistyped run name, a removed test), fails; so do the tests of a batch whose runner says it found no tests. Only a batch that writes no per-test report at all is mapped by its exit code (`--fallback-exit-code` in `args` restores the exit-code mapping for unmentioned tests). Reports sent from CI are marked `via: ci`, and each one carries the commit and a link to the job.

## Versioning

`@v1` is a moving tag. Every ZAgents release re-points it to the latest compatible version of this action. To freeze it, pin a commit SHA of `ZurabDev/zagents-releases` instead.
