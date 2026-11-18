---
name: GitHub access through Replit proxy
description: Authenticated GitHub access when Replit's global URL rewrite routes Git through its internal proxy.
---

Replit's global Git configuration may rewrite `https://github.com/` to `github.replit.internal`. A PAT supplied through askpass can still be rejected at that proxy even when authenticated GitHub API requests work.

**Why:** the Git transport was intercepted by Replit's proxy before GitHub could authenticate the PAT.

**How to apply:** if the user chooses a PAT instead of the GitHub integration, use an alternate URL prefix (such as `gh:`) rewritten directly to `https://github.com/` for Git transport. Keep the PAT in an environment variable and askpass helper; never store it in a remote URL or print it.
