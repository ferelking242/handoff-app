---
name: Handoff UI-only port
description: Scope for changing Handoff’s chat presentation.
---

When changing Handoff’s interface, keep its existing OpenHands behavior and agent/session logic unchanged. Reimplement presentation components only.

**Why:** the user explicitly asked to preserve Handoff’s working behavior while changing how its pages and components look.

**How to apply:** limit changes to screens, widgets, theme, and assets. Keep Handoff’s services, event stream, session state, caching, and notifications intact; change only presentation mappings needed to render the existing data.
