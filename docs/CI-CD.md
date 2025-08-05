# CI/CD Guide for ConfigureWSL

This document provides comprehensive information about the Continuous Integration and Continuous Deployment (CI/CD) pipeline for the ConfigureWSL PowerShell module.

## Overview

The ConfigureWSL project uses **GitHub Actions** for CI/CD automation, providing:

- **Automated Testing**: Run tests on every commit and pull request
- **Code Quality Checks**: Static analysis and quality metrics
- **Security Scanning**: Basic security vulnerability detection
- **Automated Releases**: Version management and publication
- **Multi-Platform Support**: Testing on multiple Windows versions

## Workflow Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub        │    │   CI/CD         │
│   Commits       │───▶│   Repository    │───▶│   Workflows     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                        ┌─────────────────┐    ┌─────────────────┐
                        │   PowerShell    │◀───│   Automated     │
                        │   Gallery       │    │   Release       │
                        └─────────────────┘    └─────────────────┘
```

## Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggered by**:
- Push to `main`, `master`, or `develop` branches
- Pull requests to protected branches
- Manual workflow dispatch

**Jobs**:

#### Test Job
- **Purpose**: Run comprehensive tests on multiple Windows versions
- **Matrix Strategy**: Windows Latest and Windows 2019
- **Steps**:
  1. Checkout code
  2. Setup PowerShell environment
  3. Install testing dependencies (Pester, PSScriptAnalyzer)
  4. Run PowerShell script analysis
  5. Test module import
  6. Execute full test suite with coverage
  7. Upload test results and artifacts
  8. Publish test reports
  9. Upload code coverage to Codecov

#### Validate Scripts Job
- **Purpose**: Validate all PowerShell scripts for syntax and quality
- **Steps**:
  1. Run PSScriptAnalyzer on all `.ps1`, `.psm1`, `.psd1` files
  2. Check PowerShell syntax using AST parsing
  3. Report issues and fail on errors

#### Security Scan Job
- **Purpose**: Basic security vulnerability detection
- **Steps**:
  1. Scan for hardcoded credentials patterns
  2. Check for potentially dangerous PowerShell constructs
  3. Validate secure coding practices

**Example Configuration**:
```yaml
strategy:
  fail-fast: false
  matrix:
    os: [windows-latest, windows-2019]
    include:
      - os: windows-latest
        pwsh-version: 'latest'
```

### 2. Release Workflow (`.github/workflows/release.yml`)

**Triggered by**:
- Git tags matching `v*` pattern (e.g., `v2.0.1`)
- Manual workflow dispatch with version input

**Jobs**:

#### Validate Release Job
- **Purpose**: Ensure release readiness
- **Steps**:
  1. Determine and validate version format
  2. Update module manifest with new version
  3. Install dependencies
  4. Run full test suite
  5. Create release artifacts

#### Create Release Job
- **Purpose**: Create GitHub release with assets
- **Steps**:
  1. Create release package structure
  2. Generate installation scripts
  3. Create ZIP archive
  4. Generate release notes from CHANGELOG
  5. Create GitHub release with artifacts

#### PowerShell Gallery Job
- **Purpose**: Publish to PowerShell Gallery (production releases only)
- **Requirements**: `PSGALLERY_API_KEY` secret
- **Conditions**: Non-prerelease versions only
- **Steps**:
  1. Update module version
  2. Publish to PowerShell Gallery
  3. Verify publication

#### Notification Job
- **Purpose**: Summarize release status
- **Steps**:
  1. Collect job results
  2. Display release summary
  3. Provide release URLs

### 3. Code Quality Workflow (`.github/workflows/code-quality.yml`)

**Triggered by**:
- Push to main branches
- Pull requests
- Weekly schedule (Sundays at 6 AM UTC)
- Manual workflow dispatch

**Jobs**:

#### PowerShell Analysis Job
- **Purpose**: Comprehensive static analysis
- **Steps**:
  1. Run PSScriptAnalyzer with all rules
  2. Generate detailed reports
  3. Upload analysis artifacts

#### Code Metrics Job
- **Purpose**: Calculate and track code quality metrics
- **Metrics**:
  - Lines of code
  - Function count
  - Cyclomatic complexity
  - Complexity per function
- **Output**: JSON metrics report

#### Documentation Check Job
- **Purpose**: Validate documentation quality
- **Checks**:
  - Function documentation completeness
  - README.md content quality
  - Required documentation files

## Environment Variables

### Global Environment Variables

```yaml
env:
  POWERSHELL_TELEMETRY_OPTOUT: 1  # Disable PowerShell telemetry
```

### Workflow-Specific Variables

- `ARCHIVE_PATH`: Path to release archive
- `SKIP_PUBLISH`: Flag to skip PowerShell Gallery publishing

## Secrets Management

### Required Secrets

#### `PSGALLERY_API_KEY`
- **Purpose**: PowerShell Gallery publication
- **Scope**: Repository secret
- **Usage**: Release workflow only
- **Security**: Restricted to non-prerelease versions

#### `GITHUB_TOKEN` (Automatic)
- **Purpose**: GitHub API access
- **Scope**: Automatic GitHub secret
- **Usage**: Creating releases, uploading artifacts

### Setting Up Secrets

1. Navigate to repository **Settings** → **Secrets and Variables** → **Actions**
2. Click **New repository secret**
3. Add `PSGALLERY_API_KEY` with your PowerShell Gallery API key

```powershell
# Get PowerShell Gallery API key
# 1. Visit https://www.powershellgallery.com/
# 2. Sign in and go to Account Settings
# 3. Generate new API key
# 4. Add to GitHub secrets
```

## Branch Protection

### Recommended Settings

```yaml
# .github/branch-protection.yml (if using branch protection app)
protection_rules:
  main:
    required_status_checks:
      strict: true
      contexts:
        - "Test on windows-latest"
        - "Test on windows-2019"
        - "Validate PowerShell Scripts"
        - "Security Scan"
    enforce_admins: false
    required_pull_request_reviews:
      required_approving_review_count: 1
      dismiss_stale_reviews: true
    restrictions: null
```

### Manual Configuration

1. Go to repository **Settings** → **Branches**
2. Click **Add rule** for main branch
3. Enable:
   - Require status checks to pass before merging
   - Require branches to be up to date before merging
   - Include specific status checks from CI workflow

## Artifact Management

### Test Artifacts

**Location**: Uploaded to GitHub Actions artifacts

**Files**:
- `test-results.xml`: NUnit format test results
- `coverage.xml`: JaCoCo format coverage report
- `pssa-report.json`: PSScriptAnalyzer detailed results
- `code-metrics.json`: Code quality metrics

**Retention**: 30 days

### Release Artifacts

**Location**: GitHub Releases

**Files**:
- `ConfigureWSL-{version}.zip`: Complete module package
- Source code archives (automatic)

**Retention**: Permanent

## Version Management

### Semantic Versioning

The project follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes
- **PRERELEASE**: Development versions (e.g., `2.1.0-beta.1`)

### Version Update Process

#### Automatic (Recommended)
1. Create and push a git tag:
   ```bash
   git tag v2.0.1
   git push origin v2.0.1
   ```
2. Release workflow automatically triggers
3. Module manifest updated automatically

#### Manual
1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter version number (e.g., `2.0.1`)
4. Workflow creates tag and processes release

### Version Validation

```powershell
# Version format validation regex
'^\d+\.\d+\.\d+(-[\w\d\-]+)?$'

# Examples:
# ✅ 2.0.1
# ✅ 1.5.0-beta.2
# ✅ 3.0.0-rc.1
# ❌ 2.0
# ❌ v2.0.1
# ❌ 2.0.1.4
```

## Testing Strategy

### Test Execution Matrix

| Trigger | Windows Latest | Windows 2019 | Coverage | Quality Check |
|---------|---------------|---------------|----------|---------------|
| Push    | ✅            | ✅            | ✅       | ✅            |
| PR      | ✅            | ✅            | ✅       | ✅            |
| Release | ✅            | ❌            | ✅       | ✅            |
| Weekly  | ❌            | ❌            | ❌       | ✅            |

### Test Categories in CI

1. **Unit Tests**: Function-level testing with mocking
2. **Integration Tests**: Component interaction testing
3. **Module Import Tests**: Verification of module loading
4. **Syntax Validation**: PowerShell AST parsing
5. **Static Analysis**: PSScriptAnalyzer rules
6. **Security Scanning**: Basic vulnerability detection

## Monitoring and Notifications

### Build Status

Monitor build status through:
- GitHub repository badges
- Actions tab in repository
- Email notifications (configurable)

### Status Badges

Add to README.md:
```markdown
[![CI](https://github.com/username/configure-wsl/actions/workflows/ci.yml/badge.svg)](https://github.com/username/configure-wsl/actions/workflows/ci.yml)
[![Code Quality](https://github.com/username/configure-wsl/actions/workflows/code-quality.yml/badge.svg)](https://github.com/username/configure-wsl/actions/workflows/code-quality.yml)
[![codecov](https://codecov.io/gh/username/configure-wsl/branch/main/graph/badge.svg)](https://codecov.io/gh/username/configure-wsl)
```

### Failure Notifications

Configure notifications in repository settings:
1. **Settings** → **Notifications**
2. **Actions** → Configure email/GitHub notifications
3. Set up Slack/Teams integration if needed

## Performance Optimization

### Workflow Performance

#### Caching Strategies
```yaml
- name: Cache PowerShell Modules
  uses: actions/cache@v3
  with:
    path: |
      ~/AppData/Local/PowerShell/Modules
      ~/.local/share/powershell/Modules
    key: ${{ runner.os }}-powershell-modules-${{ hashFiles('**/*.psd1') }}
```

#### Parallel Execution
- Matrix strategy for OS versions
- Parallel job execution
- Conditional job execution

#### Artifact Optimization
- Compress large artifacts
- Selective artifact uploads
- Appropriate retention periods

### Resource Management

#### Runner Usage
- Use appropriate runner sizes
- Minimize workflow duration
- Efficient dependency installation

#### Secret Access
- Limit secret scope
- Use environment-specific secrets
- Regular secret rotation

## Troubleshooting

### Common CI Issues

#### Test Failures
```powershell
# Debug test failures locally
.\tests\Invoke-Tests.ps1 -Coverage -OutputPath "./debug"

# Check specific test
Invoke-Pester -Path ".\tests\ConfigureWSL.Tests.ps1" -FullName "*failing test*"
```

#### Module Import Issues
```powershell
# Verify module manifest
Test-ModuleManifest -Path ".\src\ConfigureWSL.psd1"

# Check dependencies
Import-Module .\src\ConfigureWSL.psd1 -Force -Verbose
```

#### Permission Issues
```yaml
# Add permissions to workflow if needed
permissions:
  contents: write
  actions: read
  checks: write
```

### Debugging Workflows

#### Enable Debug Logging
1. Go to repository **Settings** → **Secrets**
2. Add `ACTIONS_STEP_DEBUG` = `true`
3. Re-run workflow for detailed logs

#### Download Artifacts
1. Go to failed workflow run
2. Download artifacts for local analysis
3. Review test results and logs

#### Local Simulation
```powershell
# Simulate CI environment locally
$env:CI = "true"
$env:GITHUB_ACTIONS = "true"
.\tests\Invoke-Tests.ps1 -CI
```

## Security Considerations

### Workflow Security

1. **Pin Action Versions**: Use specific versions (e.g., `@v4`)
2. **Limit Permissions**: Use minimal required permissions
3. **Secret Management**: Secure handling of sensitive data
4. **Code Scanning**: Regular security analysis

### Supply Chain Security

1. **Dependency Scanning**: Monitor PowerShell module dependencies
2. **Action Security**: Use trusted GitHub Actions
3. **Artifact Integrity**: Verify build artifacts

## Best Practices

### Workflow Design

1. **Fail Fast**: Stop on first failure when appropriate
2. **Clear Naming**: Use descriptive job and step names
3. **Conditional Execution**: Skip unnecessary steps
4. **Resource Efficiency**: Optimize runner usage

### Code Quality

1. **Consistent Standards**: Enforce coding standards
2. **Documentation**: Require adequate documentation
3. **Test Coverage**: Maintain high test coverage
4. **Security**: Regular security assessments

### Release Management

1. **Semantic Versioning**: Follow semver principles
2. **Release Notes**: Maintain detailed changelogs
3. **Backward Compatibility**: Minimize breaking changes
4. **Rollback Strategy**: Plan for release rollbacks

## Maintenance

### Regular Tasks

#### Weekly
- Review failed builds
- Update dependencies
- Check security advisories

#### Monthly
- Review and update workflows
- Clean up old artifacts
- Update documentation

#### Quarterly
- Review CI/CD strategy
- Performance optimization
- Security audit

### Upgrade Procedures

#### GitHub Actions Updates
1. Monitor action release notes
2. Test in feature branch
3. Update version pins
4. Deploy to main branch

#### PowerShell Module Updates
1. Test compatibility
2. Update CI configurations
3. Update documentation
4. Validate all workflows

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PowerShell in GitHub Actions](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-powershell)
- [Semantic Versioning](https://semver.org/)
- [PowerShell Gallery Publishing](https://docs.microsoft.com/en-us/powershell/scripting/gallery/how-to/publishing-packages)
- [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)