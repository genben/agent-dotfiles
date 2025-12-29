---
name: circleci
description: Check CircleCI pipeline/job status, view logs, troubleshoot CI failures, and run local builds. Use when user asks about CI status, build failures, pipeline progress, or wants to test CircleCI jobs locally.
---

# CircleCI Operations

Helper scripts for checking CircleCI pipeline status, troubleshooting failures, and running local builds.

## Prerequisites

- CircleCI CLI installed (`circleci version`)
- `CIRCLE_TOKEN` environment variable set with a CircleCI Personal API Token (for status checks)
- `jq` installed for JSON parsing
- Docker running (for local builds)

## Helper Scripts

Scripts are located in `~/.claude/skills/circleci/scripts/`:

- `circleci-status` - Check pipeline/workflow/job status
- `circleci-run-local` - Run CircleCI jobs locally

## Checking Pipeline/Job Status

Use the `circleci-status` script:

```bash
# Show latest pipeline status with workflows and jobs
~/.claude/skills/circleci/scripts/circleci-status

# Show latest pipeline for a specific branch
~/.claude/skills/circleci/scripts/circleci-status -b master

# Show workflows for a specific pipeline
~/.claude/skills/circleci/scripts/circleci-status -p <pipeline-id>

# Show jobs for a specific workflow
~/.claude/skills/circleci/scripts/circleci-status -w <workflow-id>

# Show details for a specific job
~/.claude/skills/circleci/scripts/circleci-status -j <job-number>

# Show help
~/.claude/skills/circleci/scripts/circleci-status -h
```

### Environment Variables

- `CIRCLE_TOKEN` - Required. Get from https://app.circleci.com/settings/user/tokens
- `CIRCLECI_PROJECT_SLUG` - Optional. Auto-detected from git remote origin if not set (e.g., `gh/org/repo`)

## Running CircleCI Jobs Locally

Use the `circleci-run-local` script:

```bash
# List available jobs
~/.claude/skills/circleci/scripts/circleci-run-local --list

# Run a job locally
~/.claude/skills/circleci/scripts/circleci-run-local build

# Run with environment variables
~/.claude/skills/circleci/scripts/circleci-run-local -e MY_VAR=value build

# Run without checkout step (for git worktrees)
~/.claude/skills/circleci/scripts/circleci-run-local --no-checkout build

# Show help
~/.claude/skills/circleci/scripts/circleci-run-local --help
```

### Apple Silicon (M1/M2/M3/M4) Support

CircleCI local execute works natively on Apple Silicon - no Rosetta or AMD64 emulation needed. The build agent and most CircleCI images (cimg/*) support ARM64.

### Local Execution Limitations

- `save_cache` and `restore_cache` steps are skipped
- Machine executor not supported (requires VM)
- Encrypted environment variables must be passed manually with `-e`
- Only individual jobs can be run, not full workflows
- Git worktrees require `--no-checkout` flag
- **Multi-container jobs fail on Docker Desktop** (see below)

### Multi-Container Jobs: "Invalid UTS Mode" Error

Jobs with service containers (multiple Docker images) fail locally on Docker Desktop:

```
Error: invalid UTS mode: container<id>
```

**Cause:** CircleCI local execute tries to share UTS (Unix Time-Sharing) namespace between the primary container and service containers. Docker Desktop doesn't support this mode of container linking.

**Affected jobs:** Any job defining multiple Docker images (e.g., app + postgres + redis):
```yaml
docker:
  - image: cimg/python:3.12      # primary
  - image: cimg/postgres:15.13   # service - causes UTS error
  - image: cimg/redis:6.2.18     # service - causes UTS error
```

**Single-container jobs work fine** (e.g., `build` job with only one image).

**Workarounds:**

1. **Test in actual CircleCI** - Push to a branch and let CI run

2. **Start service containers manually:**
   ```bash
   # Start services
   docker run -d --name test-postgres -e POSTGRES_USER=test -e POSTGRES_PASSWORD=test -p 5432:5432 postgres:15
   docker run -d --name test-redis -p 6379:6379 redis:7

   # Run tests pointing to local services
   TEST_DATABASE_URL=postgresql://test:test@localhost/test uv run pytest ...

   # Cleanup
   docker rm -f test-postgres test-redis
   ```

3. **Use Colima instead of Docker Desktop** (untested, may work)

**Note:** This is a Docker Desktop limitation, not a CircleCI CLI bug.

## Troubleshooting

### "Could not find picard image" Error
```bash
rm ~/.circleci/build_agent_settings.json
```

### Config Validation
```bash
circleci config validate
```

### Open Project in Browser
```bash
circleci open
```

## API Reference

For advanced usage, the scripts use CircleCI API v2:

| Purpose | Endpoint |
|---------|----------|
| List pipelines | `GET /project/{project-slug}/pipeline` |
| Get workflows | `GET /pipeline/{pipeline-id}/workflow` |
| Get jobs | `GET /workflow/{workflow-id}/job` |
| Get job details | `GET /project/{project-slug}/job/{job-number}` |

Base URL: `https://circleci.com/api/v2`
