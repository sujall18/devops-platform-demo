# Contributing

## Branch workflow

- Branch from `main`, name your branch `feat/`, `fix/`, or `ci/` prefixed
- Open a pull request — `ci.yml` runs lint, tests, and a Docker build automatically
- Terraform changes trigger a plan posted as a PR comment

## Commit style

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add DELETE /tasks/:id endpoint
fix: handle missing DB_PASSWORD env var gracefully
ci: pin trivy to v0.51.1
docs: add Grafana screenshot to README
```

## Local setup

```bash
cp .env.example .env
make dev      # starts app + postgres + pgadmin
make test     # runs pytest
make lint     # runs flake8
```

## Adding a new endpoint

1. Add the route in `app/app.py`
2. Add at least one happy-path and one error-path test in `app/tests/test_app.py`
3. Confirm `make test` and `make lint` pass before pushing
