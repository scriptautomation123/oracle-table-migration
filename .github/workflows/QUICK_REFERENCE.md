# GitHub Actions - Quick Reference

## 🚀 Quick Start

```bash
# 1. Enable GitHub Actions in repository settings
# 2. Push code to trigger workflows
# 3. View results in Actions tab
```

## 📊 Workflows at a Glance

```
┌─────────────────────────────────────────────────────────────┐
│                     Workflow Triggers                       │
├─────────────────────────────────────────────────────────────┤
│ Push to main/develop  → CI + DB Integration                │
│ Pull Request          → CI + Report Publisher              │
│ Daily 2 AM UTC        → DB Integration (scheduled)         │
│ Manual                → All workflows (on demand)          │
└─────────────────────────────────────────────────────────────┘
```

## ⚡ CI Pipeline Flow

```
Push/PR
   │
   ├──→ Code Quality (1-2 min)
   │    ├── Black (format check)
   │    ├── Flake8 (style)
   │    ├── Pylint (static analysis)
   │    └── Bandit (security)
   │
   ├──→ Unit Tests (1 min)
   │    ├── 16 tests
   │    ├── Coverage report
   │    └── Test artifacts
   │
   ├──→ Configuration Validation (<1 min)
   │    ├── Example configs
   │    ├── Script generation
   │    └── Template rendering
   │
   └──→ Summary & Reporting
        └── Status badges
```

## 📁 Key Artifacts

| Artifact | Access | Content |
|----------|--------|---------|
| `qa-dashboard.html` | Actions → Run → Artifacts | Visual test dashboard |
| `test-report.html` | Actions → Run → Artifacts | Detailed test results |
| `coverage.xml` | Actions → Run → Artifacts | Coverage data |
| `bandit-report.json` | Actions → Run → Artifacts | Security scan |

## 🎯 PR Workflow

```
1. Create PR
   ↓
2. CI runs automatically
   ↓
3. View inline summary in PR
   ↓
4. Download artifacts if needed
   ↓
5. Fix issues if any
   ↓
6. Merge when green ✅
```

## 🔍 Viewing Results

### In GitHub UI

1. **Actions Tab**
   - See all workflow runs
   - Click run to view details
   - Download artifacts

2. **PR Checks**
   - See status in PR
   - Click "Details" for logs
   - View automated comments

3. **Step Summaries**
   - Markdown tables in job
   - Visual status indicators
   - Quick metrics

### Via CLI

```bash
# List recent runs
gh run list

# View run details
gh run view <run-id>

# Download artifacts
gh run download <run-id>
```

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Tests fail | Check logs, run locally with `pytest tests/ -v` |
| Workflow doesn't trigger | Verify branch name, check Actions enabled |
| Artifacts missing | Check file paths, review job logs |
| Oracle container fails | Increase timeout, check memory |

## 📈 Metrics Dashboard

After first run, check:
- ✅ Test pass rate (target >95%)
- 📊 Code coverage (target >80%)
- 🔒 Security issues (target 0)
- ⏱️ Build time (target <5 min)

## 🔧 Manual Triggers

```
Actions Tab → Select Workflow → Run workflow → Run
```

Use for:
- Testing workflow changes
- Running DB tests on demand
- Generating fresh reports

## 📚 Documentation

- **Full Guide**: `docs/CI_CD_SETUP.md`
- **Contributing**: `CONTRIBUTING.md`
- **Workflow Details**: `.github/workflows/README.md`
- **Evaluation**: `docs/EVALUATION_SUMMARY.md`

## ⚙️ Configuration Files

```
.github/workflows/
├── ci.yml                    # Main CI pipeline
├── db-integration-test.yml   # Oracle tests
└── report-publisher.yml      # Visualization

tests/
├── test_migration.py         # 16 unit tests
└── __init__.py

pytest.ini                    # Test configuration
```

## 🎨 Badge Status

Add to your files:

```markdown
![CI](https://github.com/scriptautomation123/oracle-table-migration/actions/workflows/ci.yml/badge.svg)
![DB Tests](https://github.com/scriptautomation123/oracle-table-migration/actions/workflows/db-integration-test.yml/badge.svg)
```

## 🚨 Emergency Actions

**Stop a Running Workflow**:
1. Actions → Select run → Cancel

**Re-run Failed Jobs**:
1. Actions → Select run → Re-run jobs

**Debug Mode**:
Add to workflow:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
```

## 💡 Tips

- Run tests locally before pushing
- Use `continue-on-error: true` for non-blocking checks
- Check artifacts for detailed reports
- Monitor Actions minutes usage
- Keep workflows updated

## ✅ Checklist for New Contributors

- [ ] Read CONTRIBUTING.md
- [ ] Run tests locally: `pytest tests/ -v`
- [ ] Check formatting: `black --check .`
- [ ] Run linting: `flake8 .`
- [ ] Push and verify CI passes
- [ ] Review QA dashboard

---

**Need Help?** See full documentation in `docs/CI_CD_SETUP.md`
