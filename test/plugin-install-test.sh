#!/bin/bash
# Plugin installation integration tests for claude-orgmode
#
# Usage:
#   bash test/plugin-install-test.sh                  # Full test (requires Claude CLI)
#   bash test/plugin-install-test.sh --structure-only  # Structure validation only (no Claude CLI)
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0
STRUCTURE_ONLY=false

if [[ "${1:-}" == "--structure-only" ]]; then
    STRUCTURE_ONLY=true
fi

pass() {
    echo "  PASS: $1"
    ((PASS++))
}

fail() {
    echo "  FAIL: $1"
    ((FAIL++))
}

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# --------------------------------------------------------------------------
# Structure validation (no Claude CLI needed)
# --------------------------------------------------------------------------

echo "=== Plugin Structure Validation ==="

# marketplace.json exists and is valid JSON
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
if [[ -f "$MARKETPLACE" ]]; then
    pass "marketplace.json exists"
else
    fail "marketplace.json exists"
fi

if python3 -c "import json; json.load(open('$MARKETPLACE'))" 2>/dev/null; then
    pass "marketplace.json is valid JSON"
else
    fail "marketplace.json is valid JSON"
fi

# Required fields in marketplace.json
check_json_field() {
    local desc="$1"
    local expr="$2"
    if python3 -c "
import json, sys
data = json.load(open('$MARKETPLACE'))
result = $expr
if not result:
    sys.exit(1)
" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

check_json_field "marketplace.json has name" "data.get('name')"
check_json_field "marketplace.json has plugins array" "data.get('plugins') and len(data['plugins']) > 0"
check_json_field "marketplace.json plugin has name" "data['plugins'][0].get('name')"
check_json_field "marketplace.json plugin has source" "data['plugins'][0].get('source')"
check_json_field "marketplace.json plugin has skills" "data['plugins'][0].get('skills') and len(data['plugins'][0]['skills']) > 0"

# All skill paths exist and have SKILL.md
echo ""
echo "=== Skill Directory Validation ==="

SKILLS=$(python3 -c "
import json
data = json.load(open('$MARKETPLACE'))
for s in data['plugins'][0].get('skills', []):
    print(s)
")

for skill_path in $SKILLS; do
    # Remove leading ./ if present
    skill_path="${skill_path#./}"
    skill_dir="$REPO_ROOT/$skill_path"
    skill_md="$skill_dir/SKILL.md"

    if [[ -d "$skill_dir" ]]; then
        pass "skill directory exists: $skill_path"
    else
        fail "skill directory exists: $skill_path"
        continue
    fi

    if [[ -f "$skill_md" ]]; then
        pass "SKILL.md exists: $skill_path"
    else
        fail "SKILL.md exists: $skill_path"
        continue
    fi

    # Check YAML frontmatter has name and description
    if python3 -c "
import sys
content = open('$skill_md').read()
if not content.startswith('---'):
    sys.exit(1)
# Find closing ---
end = content.index('---', 3)
frontmatter = content[3:end]
has_name = any(line.strip().startswith('name:') for line in frontmatter.split('\n'))
has_desc = any(line.strip().startswith('description:') for line in frontmatter.split('\n'))
if not (has_name and has_desc):
    sys.exit(1)
" 2>/dev/null; then
        pass "SKILL.md has name and description: $skill_path"
    else
        fail "SKILL.md has name and description: $skill_path"
    fi
done

# Scripts and elisp
echo ""
echo "=== Core Files Validation ==="

EVAL_SCRIPT="$REPO_ROOT/scripts/claude-orgmode-eval"
if [[ -f "$EVAL_SCRIPT" ]]; then
    pass "claude-orgmode-eval exists"
else
    fail "claude-orgmode-eval exists"
fi

if [[ -x "$EVAL_SCRIPT" ]]; then
    pass "claude-orgmode-eval is executable"
else
    fail "claude-orgmode-eval is executable"
fi

MAIN_EL="$REPO_ROOT/elisp/claude-orgmode.el"
if [[ -f "$MAIN_EL" ]]; then
    pass "claude-orgmode.el exists"
else
    fail "claude-orgmode.el exists"
fi

if grep -q "^;; Version:" "$MAIN_EL" 2>/dev/null; then
    pass "claude-orgmode.el has Version header"
else
    fail "claude-orgmode.el has Version header"
fi

# Validate allowed-tools paths resolve
echo ""
echo "=== Allowed-Tools Path Validation ==="

for skill_path in $SKILLS; do
    skill_path="${skill_path#./}"
    skill_md="$REPO_ROOT/$skill_path/SKILL.md"
    [[ -f "$skill_md" ]] || continue

    # Extract unique script paths from allowed-tools that use CLAUDE_PLUGIN_ROOT
    tool_paths=$(sed -n 's/.*Bash(\${CLAUDE_PLUGIN_ROOT}\/\([^:]*\):.*/\1/p' "$skill_md" 2>/dev/null | sort -u || true)
    for rel_path in $tool_paths; do
        resolved="$REPO_ROOT/$rel_path"
        if [[ -f "$resolved" ]]; then
            pass "allowed-tools path resolves: $rel_path ($skill_path)"
        else
            fail "allowed-tools path resolves: $rel_path ($skill_path)"
        fi
    done
done

# Shared references exist
echo ""
echo "=== Shared References Validation ==="

for ref in functions.md emacsclient-usage.md installation.md troubleshooting.md; do
    if [[ -f "$REPO_ROOT/references/$ref" ]]; then
        pass "shared reference exists: $ref"
    else
        fail "shared reference exists: $ref"
    fi
done

# --------------------------------------------------------------------------
# Full installation test (requires Claude CLI)
# --------------------------------------------------------------------------

if [[ "$STRUCTURE_ONLY" == true ]]; then
    echo ""
    echo "=== Skipping installation tests (--structure-only) ==="
else
    echo ""
    echo "=== Plugin Installation Tests ==="

    if ! command -v claude >/dev/null 2>&1; then
        echo "  SKIP: Claude CLI not available"
    else
        # Validate with Claude CLI
        if claude plugin validate "$REPO_ROOT" 2>&1; then
            pass "claude plugin validate passes"
        else
            fail "claude plugin validate passes"
        fi

        # Test marketplace add from local path
        if claude plugin marketplace add "$REPO_ROOT" 2>&1; then
            pass "claude plugin marketplace add succeeds"
        else
            fail "claude plugin marketplace add succeeds"
        fi

        # Test plugin install
        if claude plugin install claude-orgmode@claude-orgmode 2>&1; then
            pass "claude plugin install succeeds"

            # Verify installed files
            CACHE_DIR=$(find ~/.claude/plugins/cache/claude-orgmode/claude-orgmode/ -maxdepth 1 -type d 2>/dev/null | tail -1)
            if [[ -n "$CACHE_DIR" && -d "$CACHE_DIR" ]]; then
                pass "plugin cache directory exists"

                check "installed: marketplace.json" test -f "$CACHE_DIR/.claude-plugin/marketplace.json"
                check "installed: claude-orgmode.el" test -f "$CACHE_DIR/elisp/claude-orgmode.el"
                check "installed: claude-orgmode-eval" test -f "$CACHE_DIR/scripts/claude-orgmode-eval"
                check "installed: skills/orgmode/SKILL.md" test -f "$CACHE_DIR/skills/orgmode/SKILL.md"
                check "installed: skills/org-roam/SKILL.md" test -f "$CACHE_DIR/skills/org-roam/SKILL.md"
                check "installed: skills/vulpea/SKILL.md" test -f "$CACHE_DIR/skills/vulpea/SKILL.md"
            else
                fail "plugin cache directory exists"
            fi

            # Cleanup
            claude plugin uninstall claude-orgmode@claude-orgmode 2>/dev/null || true
        else
            fail "claude plugin install succeeds"
        fi
    fi
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED"
    exit 1
else
    echo "ALL TESTS PASSED"
    exit 0
fi
