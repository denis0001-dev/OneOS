---
name: pr-branch
description: >-
  Fork workflow for OneOS: upstream fahadalijaved/OneOS, origin fork, try-pr-*
  branches, merge and PR hygiene. Use when syncing upstream, opening PRs, or
  pushing fork-only patches.
disable-model-invocation: true
---

# OneOS PR / fork branch workflow

## Remotes

```bash
git remote add upstream https://github.com/fahadalijaved/OneOS.git  # once
git fetch upstream
git remote -v   # origin = your fork (e.g. denis0001-dev/OneOS)
```

## Sync upstream into feature branch

```bash
git checkout try-pr-152   # example
git merge upstream/main
# On conflicts: prefer upstream unless the fork patch is still required and upstream lacks it
git push -u origin try-pr-152
```

## Open / update PR

Use `gh` against **upstream** or fork per your layout; follow repo commit style from `git log upstream/main -5`.

## Fork-only work

- Pixel guest experiments, device-specific manifests, and hotfix scripts often live on `try-pr-*` until upstreamed.
- **Do not commit** unless the user asks (see user git rules).
- After upstream merge, drop superseded fork assets (extra `switcher/assets` not in upstream `sessionScripts` break `:app:oneosFiles`).

## Related

- **patcher** — land device fixes in tree before PR.
- **android-build** — verify APK after merge.