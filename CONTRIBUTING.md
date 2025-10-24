# Contributing to Oracle Table Migration Framework

Thank you for your interest in contributing! This document provides guidelines and best practices for contributing to this project.

## 🚀 Getting Started

### Prerequisites

- Python 3.7 or higher
- Git
- Oracle Database (for integration testing)

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/scriptautomation123/oracle-table-migration.git
   cd oracle-table-migration
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   pip install pytest pytest-cov flake8 pylint black bandit
   ```

3. **Run tests**
   ```bash
   pytest tests/ -v
   ```

## 🔄 Development Workflow

### Branching Strategy

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/*` - New features
- `bugfix/*` - Bug fixes
- `hotfix/*` - Urgent production fixes

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clean, readable code
   - Follow existing code patterns
   - Add tests for new functionality
   - Update documentation

3. **Test your changes**
   ```bash
   # Run unit tests
   pytest tests/ -v
   
   # Check code formatting
   black --check generate_scripts.py lib/
   
   # Run linting
   flake8 generate_scripts.py lib/ --max-line-length=120
   
   # Security scan
   bandit -r generate_scripts.py lib/
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

5. **Push and create pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Adding or updating tests
- `refactor:` - Code refactoring
- `style:` - Code style changes (formatting, etc.)
- `chore:` - Maintenance tasks

Examples:
```
feat: add support for QUARTER interval partitioning
fix: resolve issue with hash subpartition column detection
docs: update USER_GUIDE with validation examples
test: add unit tests for config validator
```

## 🧪 Testing Guidelines

### Writing Tests

- Place tests in the `tests/` directory
- Use descriptive test names that explain what is being tested
- Follow the Arrange-Act-Assert pattern
- Test both success and failure cases

### Test Structure

```python
def test_feature_name():
    """Test description"""
    # Arrange - Set up test data
    config = {...}
    
    # Act - Execute the functionality
    result = function_under_test(config)
    
    # Assert - Verify the results
    assert result == expected_value
```

### Running Tests

```bash
# Run all tests
pytest tests/

# Run with coverage
pytest tests/ --cov=lib --cov=generate_scripts --cov-report=html

# Run specific test file
pytest tests/test_migration.py -v

# Run specific test
pytest tests/test_migration.py::TestConfigValidator::test_valid_config_structure -v
```

## 📋 Code Quality Standards

### Code Style

- Follow PEP 8 style guide
- Maximum line length: 120 characters
- Use meaningful variable and function names
- Add docstrings to all functions and classes

### Code Formatting

We use [Black](https://black.readthedocs.io/) for consistent code formatting:

```bash
# Format code
black generate_scripts.py lib/

# Check formatting without making changes
black --check generate_scripts.py lib/
```

### Linting

We use multiple linters to maintain code quality:

```bash
# Flake8 - Style guide enforcement
flake8 generate_scripts.py lib/ --max-line-length=120

# Pylint - Static analysis
pylint generate_scripts.py lib/*.py --max-line-length=120

# Bandit - Security scanning
bandit -r generate_scripts.py lib/
```

## 🔒 Security

### Security Best Practices

- Never commit secrets, passwords, or credentials
- Use environment variables for sensitive data
- Run security scans before committing: `bandit -r .`
- Report security vulnerabilities privately to maintainers

### Pre-commit Checklist

Before committing code, ensure:

- [ ] No secrets or credentials in code
- [ ] All tests pass
- [ ] Code is formatted with Black
- [ ] No linting errors
- [ ] No security issues from Bandit
- [ ] Documentation is updated

## 🤖 Continuous Integration

Our CI pipeline automatically runs on every push and pull request:

### CI Workflows

1. **Code Quality & Linting**
   - Black formatting check
   - Flake8 style guide
   - Pylint static analysis
   - Bandit security scan

2. **Unit Tests & Coverage**
   - Pytest test execution
   - Coverage report generation
   - Test result artifacts

3. **Configuration Validation**
   - Validates example configs
   - Tests script generation
   - Uploads generated scripts

4. **Database Integration Tests** (scheduled)
   - Oracle container setup
   - Integration test scenarios
   - Validation report generation

### CI Status

All CI checks must pass before a pull request can be merged.

View CI results:
- GitHub Actions tab
- PR checks section
- Downloadable test artifacts

## 📊 Visualization & Reporting

### Test Result Visualization

The CI automatically generates:

- **QA Dashboard** (HTML) - Visual overview of all test results
- **Test Reports** - Detailed test execution logs
- **Coverage Reports** - Code coverage metrics
- **Validation Reports** - Configuration validation results

Access reports from:
- GitHub Actions → Workflow Run → Artifacts
- PR comments (automatic posting)

### Adding Validation Reports

When adding new validation features:

1. Update `lib/migration_validator.py`
2. Add corresponding tests
3. Update report generation to include new metrics
4. Update documentation

## 📚 Documentation

### Required Documentation

When adding features, update:

- **README.md** - Overview and quick start
- **USER_GUIDE.md** - Detailed usage instructions
- **Code comments** - Inline documentation
- **Docstrings** - Function/class documentation
- **CHANGELOG.md** - Version history (if exists)

### Documentation Style

- Use clear, concise language
- Include code examples
- Add diagrams where helpful
- Keep formatting consistent

## 🐛 Reporting Issues

### Bug Reports

Include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (Python version, OS, Oracle version)
- Error messages and logs
- Configuration files (sanitized)

### Feature Requests

Include:
- Use case description
- Expected behavior
- Potential implementation approach
- Examples or mockups

## 🎯 Pull Request Guidelines

### Before Submitting

- [ ] Tests added/updated
- [ ] All tests pass locally
- [ ] Code formatted with Black
- [ ] No linting errors
- [ ] Documentation updated
- [ ] Commits follow convention
- [ ] No merge conflicts

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings
```

## 🏆 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- GitHub contributors graph

## 📞 Getting Help

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: docs/ directory

## 📄 License

By contributing, you agree that your contributions will be licensed under the project's MIT License.

---

Thank you for contributing to the Oracle Table Migration Framework! 🙏
