# org-roam-skill Tests

This directory contains Buttercup tests for org-roam-skill.

## Test Structure

```
test/
├── README.md                           # This file
├── test-helper.el                      # Test utilities and fixtures
├── org-roam-skill-test.el             # Unit tests
└── org-roam-skill-integration-test.el # Integration tests
```

## Test Types

### Unit Tests (`org-roam-skill-test.el`)
Tests individual functions in isolation using Buttercup's `describe`/`it` syntax:
- Tag sanitization
- Filename generation
- Doctor/diagnostic functions

### Integration Tests (`org-roam-skill-integration-test.el`)
Tests complete workflows with a temporary org-roam database:
- Note creation with various options
- Searching and querying notes
- Creating and managing links
- Tag management
- Utility functions (orphan detection, statistics)
- Edge cases and error handling

## Running Tests

### Using Eldev (Recommended)

The project uses [Eldev](https://github.com/doublep/eldev) for dependency management and testing, following org-roam's conventions.

**Prerequisites:**
- Eldev must be installed

**Install Eldev:**
```bash
curl -fsSL https://raw.github.com/doublep/eldev/master/webinstall/github-eldev | sh
```

**Run tests:**
```bash
# Install dependencies (first time only)
eldev -C --unstable prepare

# Run all tests
eldev -C --unstable test

# Run linting
eldev -C --unstable lint
```

This automatically:
- Downloads and installs org-roam and dependencies
- Runs all tests in isolation
- Reports results in Buttercup format

**Eldev provides:**
- Automatic dependency management
- Isolated package environment
- Fast iteration without rebuilds
- Consistent with org-roam's testing approach

### Interactive Development

For interactive testing during development:

```bash
# Run Eldev in interactive mode
eldev -C --unstable emacs

# Then from Emacs:
M-x buttercup-run
```

Or run specific test files:
```bash
eldev -C --unstable test test/org-roam-skill-test.el
```

## Test Coverage

### Current Coverage

**Unit Tests:**
- ✅ Tag sanitization (`org-roam-skill--sanitize-tag`)
- ✅ Filename generation (`org-roam-skill--expand-filename`)
- ✅ Diagnostic checks (`org-roam-doctor-quick`, `check-org-roam-setup`)

**Integration Tests:**
- ✅ Note creation (basic, with content, tag sanitization)
- ✅ Search (by title, by tag, by node)
- ✅ Links (bidirectional, forward links)
- ✅ Tag management (list, count, add, notes without tags)
- ✅ Utilities (orphan detection, recent notes, graph stats)
- ✅ Edge cases (empty database, nonexistent notes)

### Not Yet Covered

- Attachment functions (requires org-attach setup)
- Content search functionality
- Remove tag from note
- Multiple link insertion
- Database sync edge cases

## Writing New Tests

### Unit Test Example

```elisp
(ert-deftest my-unit-test ()
  "Test description."
  (should (equal expected-value (my-function input))))
```

### Integration Test Example

```elisp
(ert-deftest my-integration-test ()
  "Test description."
  (org-roam-skill-test-with-temp-db
   (let ((file-path (create-org-roam-note "Test" '("tag"))))
     (should (file-exists-p file-path))
     (should (org-roam-skill-test--node-exists-p "Test")))))
```

### Helper Functions

Available in `test-helper.el`:

- `org-roam-skill-test-with-temp-db` - Macro for temporary database
- `org-roam-skill-test--create-test-note` - Create test note
- `org-roam-skill-test--count-nodes` - Count nodes in database
- `org-roam-skill-test--get-note-content` - Get file content
- `org-roam-skill-test--node-exists-p` - Check if node exists

## Test Guidelines

1. **Use descriptive test names**: Prefix with `org-roam-skill-test-` or `org-roam-skill-integration-test-`
2. **Test one thing per test**: Keep tests focused and atomic
3. **Use temp database for integration tests**: Always use `org-roam-skill-test-with-temp-db` macro
4. **Clean up after tests**: The test helper handles cleanup automatically
5. **Document expected behavior**: Add clear docstrings to tests
6. **Test edge cases**: Include tests for error conditions and boundary cases

## Continuous Integration

For CI/CD pipelines (GitHub Actions, GitLab CI, etc.), use batch mode:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        emacs_version: ['27.1', '28.2', '29.1']
    steps:
      - uses: actions/checkout@v2
      - uses: purcell/setup-emacs@master
        with:
          version: ${{ matrix.emacs_version }}
      - name: Install dependencies
        run: |
          emacs --batch --eval "(require 'package)" \
            --eval "(add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\"))" \
            --eval "(package-refresh-contents)" \
            --eval "(package-install 'org-roam)"
      - name: Run tests
        run: eldev -C --unstable test
```

## Troubleshooting

### Tests fail with "org-roam not loaded"

Make sure org-roam is installed and in your load path:
```elisp
(package-install 'org-roam)
```

### Database conflicts

Tests use temporary databases that are cleaned up automatically. If you see database errors, ensure no other Emacs process is accessing the test database.

### Permission errors on temporary directories

The test suite creates temporary directories under your system temp directory. Ensure you have write permissions.

## Contributing Tests

When adding new features to org-roam-skill:

1. Add unit tests for new utility functions
2. Add integration tests for workflows
3. Update this README with coverage information
4. Ensure all tests pass before submitting PR

Run tests locally before committing:
```bash
eldev -C --unstable test
```
