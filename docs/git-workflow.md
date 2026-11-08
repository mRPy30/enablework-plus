# Local Git and remote publishing

Run from Windows PowerShell. The initial scaffold commit is 60f1140; preserve it. The owner approved a separate correction commit and normal push. Never recreate the repository, force-push, amend existing history or delete branches for this setup.

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus'
git status --short --branch
git branch --show-current
git remote -v
git log -2 --oneline
```

The origin must be https://github.com/mRPy30/enablework-plus.git. Stop if it differs. Review exactly the intended paths before staging; do not add local config or generated output.

```powershell
git diff
git diff --check
# Stage only the reviewed setup corrections:
git add -- .gitignore .vscode/extensions.json README.md docs/phase-0.md docs/supabase-setup.md docs/git-workflow.md
git diff --cached --name-status
git diff --cached --check
git diff --cached
```

If the correction commit does not yet exist, create it only after checks pass:

```powershell
git commit -m "chore: finalize Phase 0 project setup"
```

Fetch and check existing remote history without overwriting it. Run each step only if the preceding command succeeds:

```powershell
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Fetch failed. Stop before publishing or verification.' }
$branch = git branch --show-current
if ([string]::IsNullOrWhiteSpace($branch)) { throw 'A named branch is required.' }
git show-ref --verify --quiet "refs/remotes/origin/$branch"
$remoteBranchExists = $LASTEXITCODE -eq 0
if ($remoteBranchExists) {
    git merge-base --is-ancestor "origin/$branch" HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Remote history is not an ancestor. Stop and review divergence.' }
}
git push --set-upstream origin $branch
if ($LASTEXITCODE -ne 0) { throw 'Push failed. Do not report publication as successful.' }
```

A normal push will reject a concurrent non-fast-forward update. Do not force it; inspect remote work instead. After a successful push:

```powershell
git rev-parse HEAD
git ls-remote origin "refs/heads/$branch"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Fetch failed. Stop before publishing or verification.' }
git merge-base --is-ancestor 60f1140 "origin/$branch"
git log -2 --oneline "origin/$branch"
& 'C:\Program Files\GitHub CLI\gh.exe' repo view mRPy30/enablework-plus --json nameWithOwner,isPrivate,url
```

The published branch hash must match local HEAD and contain both scaffold and correction commits. isPrivate must be true. GitHub authentication is managed on the owner's Windows machine; never share credentials in chat. Authentication failure must be reported without changing login state or placing credentials in source/configuration.
