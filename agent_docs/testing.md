# Testing Guide

## Test Framework

This project uses:
- [Buttercup](https://github.com/jorgenschaefer/emacs-buttercup) - BDD testing framework for Emacs Lisp
- [Eldev](https://github.com/doublep/eldev) - Test execution and dependency management

## Test Structure

**Test files:**
- `test/org-roam-skill-test.el` - Unit tests
- `test/org-roam-skill-integration-test.el` - Integration tests
- `test/test-helper.el` - Test helpers and utilities

## Writing Tests

### Basic Test Pattern

```elisp
(describe "function-name"
  (it "describes what the test does"
    (expect (function-call args) :to-equal expected-result))

  (it "handles edge case"
    (expect (function-call edge-case) :to-match "pattern")))
```

### Common Matchers

- `:to-equal` - exact equality comparison
- `:to-match` - regex matching
- `:to-be` - identity comparison (use for `t`/`nil`)
- `:to-be-truthy` - truthy value check
- `:to-be-falsy` - falsy value check
- `:not :to-be` - negation

### Testing File Operations

Always use temporary files and clean up:

```elisp
(let ((temp-file (make-temp-file "test-" nil ".org")))
  (unwind-protect
      (progn
        ;; Test code using temp-file
        (expect (file-exists-p temp-file) :to-be t)
        ;; More test assertions...
        )
    ;; Cleanup
    (when (file-exists-p temp-file)
      (delete-file temp-file))))
```

**For directories:**
```elisp
(let ((temp-dir (make-temp-file "test-dir-" t)))
  (unwind-protect
      (progn
        ;; Test code using temp-dir
        )
    ;; Cleanup
    (when (file-directory-p temp-dir)
      (delete-directory temp-dir t))))
```

## When to Write Tests

**Required for:**
- New public API functions (all `org-roam-skill-*` functions)
- Bug fixes (add regression test)
- Edge cases and error handling
- Helper functions in modules

**Test priorities:**
1. Public API functions - highest priority
2. Core helper functions - high priority
3. Internal utilities - medium priority
4. Simple getters/setters - low priority (optional)

## Running Tests

### Quick Commands

```bash
make test      # Run all tests
make prepare   # Install test dependencies
make lint      # Run linting checks
make clean     # Remove compiled files and cache
```

### Detailed Test Execution

**Run all tests with verbose output:**
```bash
eldev -C --unstable test
```

**Run specific test file:**
```bash
eldev -C --unstable test test/org-roam-skill-test.el
```

**Run tests matching pattern:**
```bash
eldev -C --unstable test --pattern "sanitize"
```

**Run with coverage report:**
```bash
eldev -C --unstable test --coverage
```

## Pre-Commit Checklist

Before committing changes:

1. ✓ Run `make test` - all tests must pass
2. ✓ Run `make lint` - no linting errors
3. ✓ Add tests for new functionality
4. ✓ Update tests if changing existing behavior
5. ✓ Ensure tests are descriptive and clear

## Test Organization Best Practices

**Group related tests:**
```elisp
(describe "org-roam-skill-create-note"
  (describe "with default template"
    (it "creates file with proper structure"
      ...))

  (describe "with custom template"
    (it "expands placeholders correctly"
      ...)))
```

**Use descriptive test names:**
- Good: `"replaces hyphens with underscores in tags"`
- Bad: `"tag test 1"`

**Keep tests focused:**
- One logical assertion per test
- Test one behavior at a time
- Use multiple tests for multiple behaviors

## Debugging Failed Tests

**Run single test with debug output:**
```bash
eldev -C --unstable test --pattern "specific-test-name" --verbose
```

**Add debug output in tests:**
```elisp
(it "debugs something"
  (let ((result (function-call)))
    (message "Debug: result is %S" result)
    (expect result :to-equal expected)))
```

**Use `buttercup-define-matcher` for custom matchers:**
See existing test files for examples of custom matchers.
