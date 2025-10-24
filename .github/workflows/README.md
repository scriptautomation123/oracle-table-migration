# GitHub Actions Workflows

This directory contains the CI/CD workflows for the Oracle Table Migration Framework.

## Workflows Overview

### 1. CI - Lint, Test, and Validate (`ci.yml`)

**Purpose**: Main continuous integration pipeline

**Runs on**: 
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual trigger

**Jobs**:
- **lint**: Code quality checks (Black, Flake8, Pylint, Bandit)
- **test**: Unit tests with coverage reporting
- **validation**: Configuration validation and script generation
- **summary**: Aggregate results and status reporting

**Artifacts**:
- `security-report` - Bandit security scan results
- `test-results` - Pytest HTML and JSON reports
- `coverage-report` - Code coverage data
- `generated-scripts-sample` - Sample migration scripts

### 2. Database Integration Tests (`db-integration-test.yml`)

**Purpose**: End-to-end testing with Oracle database

**Runs on**:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Schedule: Daily at 2 AM UTC
- Manual trigger (with Oracle version selection)

**Features**:
- Oracle XE 21c container setup
- Schema discovery testing
- Migration validation
- Script generation verification

**Artifacts**:
- `integration-test-results` - Test outputs
- `integration-test-report` - Markdown summary

### 3. Validation Report Publisher (`report-publisher.yml`)

**Purpose**: Aggregate and visualize test results

**Runs on**:
- After CI workflow completes
- After DB Integration workflow completes
- Manual trigger

**Features**:
- Combines results from all workflows
- Generates HTML QA Dashboard
- Posts status to pull requests
- Creates visual metrics

**Artifacts**:
- `qa-dashboard.html` - Visual test dashboard (90-day retention)

## Viewing Results

### GitHub UI

1. Go to **Actions** tab in GitHub
2. Select a workflow run
3. View job results and logs
4. Download artifacts from the bottom of the page

### Pull Requests

Automated comments will be posted with:
- Test status summary
- Links to artifacts
- Quick status indicators

### Job Summaries

Each workflow generates markdown summaries visible in:
- Workflow run page
- Summary tab of each job

## Artifacts

All artifacts are retained for 7-90 days depending on type:

| Artifact | Format | Retention |
|----------|--------|-----------|
| Test Results | HTML, JSON | 30 days |
| Coverage Reports | HTML, XML | 30 days |
| Security Scans | JSON | 30 days |
| QA Dashboard | HTML | 90 days |
| Generated Scripts | SQL | 7 days |

### Downloading Artifacts

**Via GitHub UI**:
1. Navigate to workflow run
2. Scroll to "Artifacts" section
3. Click artifact name to download

**Via GitHub CLI**:
```bash
gh run download <run-id> -n <artifact-name>
```

## Customization

### Modifying Workflows

1. Edit workflow YAML files in this directory
2. Test in a feature branch first
3. Use `workflow_dispatch` for manual testing
4. Monitor first production run

### Adding New Checks

To add new quality checks:

1. Add to `ci.yml` in the appropriate job
2. Update job dependencies if needed
3. Add artifact upload if generating reports
4. Update documentation

Example:
```yaml
- name: New Check
  run: |
    your-command-here
  continue-on-error: true

- name: Upload New Check Results
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: new-check-results
    path: results.json
```

### Configuring Oracle Tests

To use a different Oracle version:

1. Update `services.oracle.image` in `db-integration-test.yml`
2. Adjust health check if needed
3. Update test scripts for version-specific features

## Troubleshooting

### Common Issues

**Tests fail locally but pass in CI**:
- Check Python version matches CI (3.11)
- Verify dependencies are installed
- Check for environment-specific issues

**Workflow doesn't trigger**:
- Verify branch name matches trigger conditions
- Check if Actions are enabled in repository settings
- Review workflow permissions

**Artifacts not uploading**:
- Check file paths are correct
- Verify files exist after job runs
- Check artifact size limits (500 MB)

**Oracle container fails**:
- Increase health check timeout
- Verify memory allocation
- Check container logs

### Debug Mode

Enable debug logging:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Getting Help

- Review workflow logs in GitHub Actions
- Check [CI/CD Setup Documentation](../docs/CI_CD_SETUP.md)
- Open issue with workflow run link
- Review [Troubleshooting Guide](../docs/CI_CD_SETUP.md#troubleshooting)

## Best Practices

### When Modifying Workflows

✅ **Do**:
- Test changes in feature branches
- Use descriptive job and step names
- Add comments for complex logic
- Update documentation
- Version pin action dependencies

❌ **Don't**:
- Commit secrets to workflow files
- Make breaking changes without testing
- Remove error handling
- Skip documentation updates

### Performance Tips

- Use caching for dependencies
- Run expensive tests in scheduled workflows
- Parallelize independent jobs
- Set appropriate timeouts
- Use `continue-on-error` for non-critical checks

## Security

### Secrets Management

Never commit secrets to workflows. Use GitHub Secrets:

```yaml
env:
  DB_PASSWORD: ${{ secrets.ORACLE_PASSWORD }}
```

### Permissions

Workflows use minimal required permissions:
- `contents: read` - Read repository contents
- `pull-requests: write` - Comment on PRs
- `issues: write` - Create/update issues

## Maintenance

### Regular Tasks

**Weekly**:
- Review failed workflows
- Check artifact storage usage

**Monthly**:
- Update action versions
- Review and clean old artifacts
- Assess workflow performance

**Quarterly**:
- Review workflow efficiency
- Update documentation
- Optimize job execution

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax Reference](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Project CI/CD Setup Guide](../docs/CI_CD_SETUP.md)
- [Contributing Guidelines](../CONTRIBUTING.md)

---

**Last Updated**: 2025-10-24
**Version**: 1.0
