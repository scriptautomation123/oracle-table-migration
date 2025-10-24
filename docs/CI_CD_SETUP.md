# CI/CD Documentation - Oracle Table Migration Framework

## Overview

This document describes the Continuous Integration and Continuous Deployment (CI/CD) setup for the Oracle Table Migration Framework, including workflows, best practices, and visualization of database QA testing results.

## Table of Contents

- [Architecture](#architecture)
- [Workflows](#workflows)
- [Test Visualization](#test-visualization)
- [Database QA Testing](#database-qa-testing)
- [Artifacts & Reports](#artifacts--reports)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Architecture

### CI/CD Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                          │
└─────────────────────────────────────────────────────────────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
        ┌───────▼────────┐ ┌────▼─────┐ ┌───────▼────────┐
        │  Code Quality  │ │   Unit   │ │  Integration   │
        │   & Linting    │ │  Tests   │ │     Tests      │
        └───────┬────────┘ └────┬─────┘ └───────┬────────┘
                │                │                │
                └────────────────┼────────────────┘
                                 │
                        ┌────────▼─────────┐
                        │  Validation &    │
                        │    Reporting     │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │   Artifacts &    │
                        │  Visualization   │
                        └──────────────────┘
```

### Workflow Triggers

| Event | Workflows Triggered | Purpose |
|-------|-------------------|---------|
| Push to main/develop | CI, DB Integration | Validate all changes |
| Pull Request | CI, Report Publisher | Pre-merge validation |
| Schedule (Daily 2 AM) | DB Integration | Nightly regression tests |
| Manual (workflow_dispatch) | All | On-demand testing |

## Workflows

### 1. CI - Lint, Test, and Validate (`ci.yml`)

**Purpose**: Primary CI pipeline for code quality, testing, and configuration validation.

**Jobs**:

#### 1.1 Code Quality & Linting
- **Black**: Code formatting verification
- **Flake8**: PEP 8 style guide enforcement
- **Pylint**: Static code analysis
- **Bandit**: Security vulnerability scanning

```yaml
Artifacts:
- security-report.json (Security scan results)
```

#### 1.2 Unit Tests & Coverage
- **Pytest**: Execute unit test suite
- **Coverage**: Generate code coverage reports
- **Test Reports**: HTML and JSON test results

```yaml
Artifacts:
- test-report.html (Human-readable test results)
- test-results.json (Machine-readable results)
- htmlcov/ (Coverage report)
- coverage.xml (Coverage data)
```

#### 1.3 Configuration Validation
- Validates all example configurations
- Tests script generation
- Verifies template rendering

```yaml
Artifacts:
- generated-scripts-sample/ (Sample migration scripts)
```

#### 1.4 CI Summary
- Aggregates results from all jobs
- Generates unified summary
- Posts status to GitHub

### 2. Database Integration Tests (`db-integration-test.yml`)

**Purpose**: End-to-end testing with Oracle database.

**Infrastructure**:
- Oracle XE 21c container (via GitHub Services)
- Test schema setup
- Sample data population

**Test Scenarios**:
1. Schema discovery
2. Configuration generation
3. Script generation
4. Pre-migration validation
5. Post-migration validation (when applicable)

```yaml
Artifacts:
- integration-test-results/ (Test outputs)
- integration-test-report.md (Summary report)
```

**Schedule**: Daily at 2 AM UTC + on-demand

### 3. Validation Report Publisher (`report-publisher.yml`)

**Purpose**: Aggregate and visualize test results across all workflows.

**Features**:
- Combines results from all test runs
- Generates comprehensive HTML dashboard
- Posts summary to pull requests
- Creates historical trend data

```yaml
Artifacts:
- qa-dashboard.html (Visual test dashboard)
```

**Trigger**: Runs after CI and DB Integration workflows complete

## Test Visualization

### QA Dashboard

The QA Dashboard provides a comprehensive, visual overview of all test results:

**Metrics Displayed**:
- ✅ Test pass rate (percentage)
- 📊 Code coverage (percentage)
- ✓ Configuration validation status
- 🔒 Security scan results
- ⏱️ Test execution duration

**Access**: 
- GitHub Actions → Workflow Run → Artifacts → `qa-dashboard.html`
- Download and open in browser

### Test Result Tables

Results are presented in easy-to-read tables:

| Test Suite | Status | Passed | Failed | Duration |
|------------|--------|--------|--------|----------|
| Unit Tests | ✓ Passed | X | 0 | Xs |
| Integration Tests | ✓ Passed | X | 0 | Xs |
| Config Validation | ✓ Passed | X | 0 | <1s |

### GitHub Step Summaries

Each workflow generates markdown summaries visible in the GitHub UI:

**Example Summary**:
```markdown
## Test Results Summary 🧪

| Metric | Count |
|--------|-------|
| ✅ Passed | 45 |
| ❌ Failed | 0 |
| ⚠️ Skipped | 2 |
| 🕐 Duration | 12.34s |

## Configuration Validation Results 📋

| Config File | Status | Issues |
|-------------|--------|--------|
| config_interval_to_interval_hash.json | ✅ Valid | None |
| config_nonpartitioned_to_interval_hash.json | ✅ Valid | None |
```

### Pull Request Comments

Automated PR comments provide at-a-glance status:

```markdown
## 📊 QA Test Results

### Summary
- ✅ Code quality checks: Passed
- ✅ Configuration validation: Passed
- ✅ Security scan: No issues

### Artifacts
- [View QA Dashboard](...)
- [Download Test Reports](...)
```

## Database QA Testing

### Test Coverage

| Category | Tests | Description |
|----------|-------|-------------|
| **Discovery** | Schema scanning | Validates table metadata extraction |
| **Validation** | Config validation | Ensures JSON schema compliance |
| **Generation** | Script generation | Verifies SQL script creation |
| **Pre-migration** | Prerequisites | Checks table structure, storage, dependencies |
| **Post-migration** | Verification | Validates partition config, row counts |
| **Data Comparison** | Data integrity | Compares row counts, samples, distribution |

### Oracle Integration Tests

**Test Environment**:
- Oracle XE 21c (slim image)
- Automated schema setup
- Sample data population

**Test Scenarios**:

1. **Non-Partitioned → Interval**
   - Discovers non-partitioned tables
   - Generates config with DAY interval
   - Creates migration scripts
   - Validates prerequisites

2. **Interval → Interval-Hash**
   - Discovers interval-partitioned tables
   - Adds hash subpartitioning
   - Validates complex partition schemes

3. **Configuration Edge Cases**
   - Invalid interval types
   - Missing required fields
   - Incompatible partition schemes

### Validation Reports

Migration validation reports include:

**Pre-Migration Checks**:
- ✅ Table structure validation
- ✅ Storage space availability
- ✅ Dependency checks (indexes, constraints)
- ✅ Privilege verification

**Post-Migration Checks**:
- ✅ Partition configuration
- ✅ Row count comparison
- ✅ Index validation
- ✅ Grant restoration

**Data Comparison**:
- ✅ Total row counts match
- ✅ Sample data comparison
- ✅ Distribution analysis

## Artifacts & Reports

### Artifact Types

| Artifact | Format | Retention | Description |
|----------|--------|-----------|-------------|
| Test Results | HTML, JSON | 30 days | Detailed test execution logs |
| Coverage Report | HTML, XML | 30 days | Code coverage metrics |
| Security Report | JSON | 30 days | Vulnerability scan results |
| QA Dashboard | HTML | 90 days | Visual test summary |
| Generated Scripts | SQL | 7 days | Sample migration scripts |
| Integration Reports | Markdown | 30 days | DB test summaries |

### Accessing Artifacts

**Via GitHub UI**:
1. Go to Actions tab
2. Select workflow run
3. Scroll to Artifacts section
4. Click artifact name to download

**Via GitHub CLI**:
```bash
# List artifacts for a run
gh run view <run-id> --log

# Download artifact
gh run download <run-id> -n <artifact-name>
```

### Report Formats

#### HTML Dashboard
- Interactive visual dashboard
- Color-coded status indicators
- Sortable tables
- Downloadable

#### JSON Reports
- Machine-readable format
- Integration with external tools
- Historical data analysis

#### Markdown Reports
- Human-readable summaries
- Embedded in GitHub UI
- PR-friendly format

## Best Practices

### For Developers

1. **Run Tests Locally**
   ```bash
   # Before pushing
   pytest tests/ -v
   black --check .
   flake8 .
   ```

2. **Keep Tests Fast**
   - Unit tests should run in seconds
   - Use mocking for external dependencies
   - Reserve integration tests for critical paths

3. **Write Meaningful Tests**
   - Test behavior, not implementation
   - Use descriptive test names
   - Cover edge cases

4. **Monitor CI Results**
   - Check GitHub Actions after push
   - Review failed test logs
   - Fix issues promptly

### For Reviewers

1. **Check CI Status**
   - All checks must pass
   - Review test coverage changes
   - Examine security scan results

2. **Review Test Changes**
   - New features should have tests
   - Test quality matters
   - Coverage shouldn't decrease

3. **Validate Artifacts**
   - Download and review QA dashboard
   - Check validation reports
   - Verify generated scripts

### For Maintainers

1. **Monitor Trends**
   - Track test pass rates over time
   - Watch for coverage regressions
   - Review security scan trends

2. **Update Workflows**
   - Keep actions up to date
   - Adjust retention policies
   - Optimize performance

3. **Manage Resources**
   - Clean up old artifacts
   - Monitor workflow minutes
   - Optimize job parallelization

## Troubleshooting

### Common Issues

#### Tests Fail Locally but Pass in CI

**Cause**: Environment differences
**Solution**:
```bash
# Use same Python version as CI
python3.11 -m pytest tests/

# Check for local config files
git status --ignored
```

#### CI Times Out

**Cause**: Long-running tests or commands
**Solution**:
- Increase timeout in workflow
- Optimize slow tests
- Use caching for dependencies

#### Artifacts Not Uploading

**Cause**: Path issues or size limits
**Solution**:
```yaml
# Use absolute paths
- uses: actions/upload-artifact@v4
  with:
    path: ${{ github.workspace }}/reports/
```

#### Oracle Container Fails to Start

**Cause**: Resource limits or timeout
**Solution**:
- Increase health check timeout
- Verify memory allocation
- Check Oracle container logs

### Debug Mode

Enable debug logging in workflows:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Viewing Logs

**Workflow Logs**:
1. Actions tab → Select workflow run
2. Click job name
3. Expand step to view logs

**Artifact Logs**:
1. Download artifact
2. Extract and view local files

## Maintenance

### Regular Tasks

**Weekly**:
- Review failed test trends
- Check artifact storage usage
- Update dependencies if needed

**Monthly**:
- Review and update workflows
- Clean up old artifacts manually if needed
- Assess coverage trends

**Quarterly**:
- Update GitHub Actions versions
- Review security scan configuration
- Optimize workflow performance

### Updating Workflows

When updating workflows:
1. Test in feature branch first
2. Use workflow_dispatch for manual testing
3. Monitor first production run carefully
4. Update documentation

## Metrics & KPIs

### Track These Metrics

- **Test Pass Rate**: Target >95%
- **Code Coverage**: Target >80%
- **Build Time**: Monitor for regressions
- **Security Issues**: Target 0 critical
- **Artifact Size**: Monitor storage usage

### Dashboard Recommendations

Consider setting up external dashboards using:
- GitHub Actions badges
- Custom reporting scripts
- Integration with monitoring tools

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [pytest Documentation](https://docs.pytest.org/)
- [Coverage.py Documentation](https://coverage.readthedocs.io/)
- [Bandit Security Scanner](https://bandit.readthedocs.io/)

## Support

For CI/CD issues:
1. Check this documentation
2. Review workflow logs
3. Open GitHub issue with:
   - Workflow run link
   - Error messages
   - Environment details

---

**Last Updated**: 2025-10-24
**Version**: 1.0
**Maintainers**: Project team
