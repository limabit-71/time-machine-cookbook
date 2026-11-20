#!/usr/bin/env bash
# check.sh : checks your git missions. Run it in the project folder:
#     bash scripts/check.sh m1        (one mission)
#     bash scripts/check.sh all       (all missions)
# It only READS your repo. It never changes anything.

PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
hint() { echo "        hint: $1"; }

in_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
first_commit() { git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1; }
count_commits() { git rev-list --count HEAD 2>/dev/null; }
count_merges() { git rev-list --merges --count HEAD 2>/dev/null; }
new_recipes() { ls recipes/*.html 2>/dev/null | grep -v 'recipes/pasta.html'; }
markers() { git grep -n -e '^<<<<<<<' -e '^>>>>>>>' -- . ':!scripts' 2>/dev/null; }

m1() {
  echo "Mission 1: Launch"
  in_repo && ok "this folder is a git repository" || { bad "this folder is not a git repository"; hint "run: git init"; return; }
  [ "$(count_commits)" -ge 1 ] 2>/dev/null && ok "you have at least one commit" || { bad "no commit yet"; hint "git add .  then  git commit -m \"Start the cookbook\""; return; }
  git ls-files --error-unmatch index.html style.css >/dev/null 2>&1 && ok "index.html and style.css are tracked" || bad "index.html or style.css is not tracked (git add .)"
  [ -z "$(git status --porcelain)" ] && ok "the working tree is clean" || { bad "you have changes that are not committed"; hint "run git status and read it"; }
}
m2() {
  echo "Mission 2: Your first recipe"
  in_repo || { bad "not a git repository"; return; }
  files=$(new_recipes)
  [ -n "$files" ] && ok "you added a recipe page" || { bad "no new file in recipes/"; hint "cp template-recipe.html recipes/yourname-recipe.html"; return; }
  linked=1; for f in $files; do grep -q "recipes/$(basename "$f")" index.html || linked=0; done
  [ "$linked" = 1 ] && ok "index.html links to your recipe" || { bad "index.html does not link to your recipe"; hint "add a <li><a href=...> line below the comment"; }
  grep -q 'RECIPE NAME\|YOUR NAME\|INGREDIENT 1' $files && bad "your recipe still has template words (RECIPE NAME, YOUR NAME ...)" || ok "the template words are replaced"
  f1=$(echo "$files" | head -1)
  h=$(git log --diff-filter=A --format=%H -- "$f1" | tail -1)
  if [ -n "$h" ]; then
    if git show --name-only --format= "$h" | grep -q '^index.html$'; then bad "the recipe page and the link are in the same commit"; hint "one idea per commit: two commits, one for the page, one for the link"; else ok "the page and the link are in separate commits (one idea per commit)"; fi
  else bad "the recipe page is not committed yet"; fi
  [ "$(count_commits)" -ge 3 ] && ok "at least three commits in total" || bad "you need at least three commits"
}
m3() {
  echo "Mission 3: Style it, and ignore a file"
  in_repo || { bad "not a git repository"; return; }
  fc=$(first_commit)
  git diff --quiet "$fc" HEAD -- style.css && { bad "style.css is the same as in the first commit"; hint "change the --accent colour, then commit"; } || ok "you changed style.css, and committed it"
  grep -q '^todo.txt$' .gitignore 2>/dev/null && ok ".gitignore contains todo.txt" || { bad "todo.txt is not in .gitignore"; hint "echo todo.txt >> .gitignore"; }
  [ -f todo.txt ] && ok "todo.txt exists on your computer" || bad "todo.txt does not exist: create it with nano todo.txt"
  git ls-files --error-unmatch todo.txt >/dev/null 2>&1 && bad "todo.txt is tracked by git (it should be ignored)" || ok "git ignores todo.txt"
  git ls-files --error-unmatch .gitignore >/dev/null 2>&1 && [ -z "$(git status --porcelain)" ] && ok "everything is committed" || bad "you have changes that are not committed"
}
m4() {
  echo "Mission 4: Oops! (undo)"
  in_repo || { bad "not a git repository"; return; }
  [ -z "$(git status --porcelain)" ] && ok "the working tree is clean: your mistakes are undone" || { bad "there are still changes"; hint "git restore <file>  or  git restore --staged <file>"; }
  grep -q '<h1>' index.html && ok "index.html still has its heading" || bad "the heading in index.html is missing: git restore index.html"
  [ -z "$(git diff --cached --name-only)" ] && ok "nothing is staged by mistake" || bad "something is still staged: git restore --staged <file>"
}
m5() {
  echo "Mission 5: Time travel"
  in_repo || { bad "not a git repository"; return; }
  git ls-files --error-unmatch answers.md >/dev/null 2>&1 && ok "answers.md is committed" || { bad "answers.md is not committed"; hint "cp answers-template.md answers.md, fill it in, add, commit"; return; }
  n=$(grep -c -E '^A[1-4]: *[^ ]' answers.md)
  [ "$n" -ge 4 ] && ok "all four answers are filled in" || { bad "only $n of 4 answers are filled in (write after A1: A2: A3: A4:)"; }
}
m6() {
  echo "Mission 6: Branch out"
  in_repo || { bad "not a git repository"; return; }
  merged=$(git branch --merged | sed 's/^[* ]*//' | grep -v '^main$' | grep -v '^master$')
  [ -n "$merged" ] && ok "you merged a branch into main: $(echo $merged | tr '\n' ' ')" || { bad "no feature branch has been merged"; hint "git switch -c <branch>, commit, git switch main, git merge <branch>"; }
  [ "$(count_merges)" -ge 1 ] && ok "your history has a merge commit (a three-way merge)" || { bad "no merge commit yet: make main move first, then merge the second branch"; }
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] && ok "you are back on main" || bad "switch back to main: git switch main"
}
m7() {
  echo "Mission 7: Conflict dojo"
  in_repo || { bad "not a git repository"; return; }
  [ -z "$(markers)" ] && ok "no conflict markers are left in your files" || { bad "conflict markers are still in a file:"; markers | head -3; return; }
  [ "$(count_merges)" -ge 2 ] && ok "you have at least two merge commits (mission 6 and mission 7)" || bad "you need a second merge commit: the one that fixed the conflict"
  grep -q 'class="tagline"' index.html && ok "the tagline is still in index.html" || bad "the tagline line is missing from index.html"
  [ -z "$(git status --porcelain)" ] && ok "the merge is finished (clean working tree)" || bad "the merge is not finished: git add, then git commit"
}
m8() {
  echo "Mission 8: Go online"
  in_repo || { bad "not a git repository"; return; }
  url=$(git remote get-url origin 2>/dev/null)
  [ -n "$url" ] && ok "you have a remote called origin: $url" || { bad "no remote yet"; hint "git remote add origin <url>"; return; }
  git rev-parse --verify origin/main >/dev/null 2>&1 && ok "main is on GitHub (origin/main exists)" || { bad "origin/main does not exist: git push --set-upstream origin main"; return; }
  [ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] && ok "your main and origin/main are the same" || bad "local main and origin/main are different: git push, or git pull"
}
m9() {
  echo "Mission 9: Team recipes"
  in_repo || { bad "not a git repository"; return; }
  n=$(grep -c '<li><a href="recipes/' index.html)
  [ "$n" -ge 3 ] && ok "index.html lists $n recipes (the class recipe and at least two more)" || { bad "index.html lists only $n recipes: it should have at least 3"; hint "after the merges: git switch main, git pull"; }
  [ -z "$(markers)" ] && ok "no conflict markers are left" || bad "conflict markers are still in a file"
  [ "$(count_merges)" -ge 3 ] && ok "at least three merge commits in your history" || bad "fewer than three merge commits: the pull requests and your merges are missing"
  [ -z "$(git status --porcelain)" ] && ok "clean working tree" || bad "uncommitted changes"
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] && ok "you are on main" || bad "git switch main, then git pull"
}
m10() {
  echo "Mission 10 (bonus): Release"
  in_repo || { bad "not a git repository"; return; }
  [ -n "$(git tag -l 'v*')" ] && ok "you made a tag: $(git tag -l 'v*' | head -1)" || { bad "no tag yet"; hint "git tag v1.0"; }
}

case "$1" in
  m1|m2|m3|m4|m5|m6|m7|m8|m9|m10) "$1" ;;
  all) for x in m1 m2 m3 m4 m5 m6 m7 m8 m9; do "$x"; done ;;
  *) echo "Usage: bash scripts/check.sh m1 .. m10   or   bash scripts/check.sh all"; exit 2 ;;
esac
echo
if [ "$FAIL" -eq 0 ]; then echo "ALL CHECKS PASSED ($PASS). Well done, time traveller."; else echo "$FAIL check(s) need your attention, $PASS passed. Read the hints, fix, and run the check again."; fi
[ "$FAIL" -eq 0 ]
