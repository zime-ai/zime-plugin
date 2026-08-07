#!/bin/bash
# Zero-dependency check that README.md agrees with skills/*. Simplified
# variant of the open repo's script, matched to this README's two surfaces:
# the skills badge count and the SKILLS:START..END table. Run from the
# repo root.
#
# Usage: ./scripts/check-docs-sync.sh [root-dir]   (default: current directory)

ROOT="${1:-.}"
cd "$ROOT" || { echo "No such directory: $ROOT" >&2; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SKILLS_DIR="skills"
README="README.md"
ISSUES=0

echo "Checking README.md against skills/*"
echo "================================================================"
echo ""

actual_count=$(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')

# --- 1. Badge count -------------------------------------------------------

badge=$(grep -oE 'skills-[0-9]+-blue' "$README")
if [[ -z "$badge" ]]; then
    echo -e "${RED}FAIL${NC} skills badge not found in README.md"
    ((ISSUES++))
else
    n=$(grep -oE '[0-9]+' <<< "$badge" | head -1)
    if [[ "$n" != "$actual_count" ]]; then
        echo -e "${RED}FAIL${NC} badge says $n skills, but $actual_count skill dirs exist"
        ((ISSUES++))
    fi
fi

# --- 2/3. SKILLS:START..END table vs. actual skill dirs -------------------

table_block=$(awk '/<!-- SKILLS:START -->/{f=1;next}/<!-- SKILLS:END -->/{f=0}f' "$README")
table_skills=$(grep -oE '\[[a-z0-9-]+\]\(skills/[a-z0-9-]+/\)' <<< "$table_block" \
    | sed -E 's/\[([a-z0-9-]+)\].*/\1/' | sort -u)
actual_skills=$(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | xargs -n1 basename | sort)

missing=0
while read -r s; do
    [[ -z "$s" ]] && continue
    echo -e "${RED}FAIL${NC} $s exists in skills/ but has no row in the Available skills table"
    ((missing++))
done < <(comm -23 <(echo "$actual_skills") <(echo "$table_skills"))
((ISSUES += missing))

orphans=0
while read -r s; do
    [[ -z "$s" ]] && continue
    echo -e "${RED}FAIL${NC} $s has a table row but no matching skills/ directory"
    ((orphans++))
done < <(comm -13 <(echo "$actual_skills") <(echo "$table_skills"))
((ISSUES += orphans))

echo ""
echo "================================================================"
if [[ $ISSUES -gt 0 ]]; then
    echo -e "${RED}$ISSUES issue(s)${NC} — README.md is out of sync with skills/"
    exit 1
else
    echo -e "${GREEN}README.md matches skills/${NC} ($actual_count skills)"
fi
