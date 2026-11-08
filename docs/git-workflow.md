# Local Git and remote publishing

The owner verified mRPy30/enablework-plus as private and empty from authenticated Windows PowerShell. The scaffold does not independently access or modify GitHub.

After reviewing the local milestone, run in Windows PowerShell:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus'
git status --short --branch
git remote -v
git log -1 --oneline
git ls-remote origin
```

The origin must be https://github.com/mRPy30/enablework-plus.git. If ls-remote fails, stop. If any remote refs appear, stop and inspect them before pushing; do not force-push. If origin is absent, add it with:

```powershell
git remote add origin https://github.com/mRPy30/enablework-plus.git
```

If no initial local commit exists, review and create it:

```powershell
git add .
git diff --cached --name-status
git diff --cached
# Continue only after reviewing all staged content.
git commit -m "Initial commit: EnableWork+ project setup"
```

After explicit approval to publish and a successful empty-remote check:

```powershell
git push -u origin main
git rev-parse HEAD
git ls-remote origin refs/heads/main
& 'C:\Program Files\GitHub CLI\gh.exe' repo view mRPy30/enablework-plus --json nameWithOwner,isPrivate,url
```

The local and remote main hashes must match. Confirm isPrivate is true. Never share credentials in chat. Do not create another repository or rerun git init over this checkout.
