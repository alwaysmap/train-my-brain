# Serve and deliver

Loaded at the end of `/tmb:create` (Phase 10 + Phase 11). Holds the tmux readiness logic and the delivery-block template so the SKILL workflow stays tight.

## Phase 10: Serve

Try to start the dev server in the background. The two failure modes that have actually happened in production: tmux is missing, or the port is already in use. Both fall back gracefully.

```bash
if command -v tmux >/dev/null 2>&1; then
  tmux new-session -d -s "tmb-<slug>" "cd '<target>' && ./serve.sh"
  # Readiness probe — 15 seconds max.
  for i in {1..30}; do
    if curl -fsS -o /dev/null "http://localhost:1313/"; then
      server_ready=true
      break
    fi
    sleep 0.5
  done
else
  server_ready=false
fi
```

Branch on `server_ready`:

- **True** — site is live at `http://localhost:1313`.
- **False** — print the manual instruction with diagnostics:

  ```
  Server didn't start automatically. Start it manually:
    cd <target> && ./serve.sh

  If the port is already in use:
    lsof -i :1313        (find what's using 1313)
    cd <target> && ./stop.sh   (if it's an old TMB serve)
  ```

Do not hang. 15 seconds is the absolute ceiling on the probe. Match the actual state in Phase 11 — don't print the success block if the fallback fired.

## Phase 11: Deliver

Print this block, substituting the runtime values:

```
[11 of 11] Your curriculum is ready.

🌐 Site:   http://localhost:1313
📁 Folder: file://<target>/

↻ Restart server: cd <target> && ./serve.sh
✖ Stop server:    cd <target> && ./stop.sh
🔧 Rebuild site:  cd <target> && ./build.sh

Research substrate: <target>/research.yaml
  - <N> canonical glossary entries (every module shares them)
  - <M> sourced reading entries with section anchors
  - <K> identified contrasts

Review: <target>/review.md
  - Mechanical fixes applied: <N>
  - Substantive flags waiting: <K>

Daily use:
  README.md in the curriculum folder has the run/stop/edit/publish recap.

Want to publish to GitHub Pages?
  cd <target> && claude
  Then run: /tmb:publish
  (Walks you through gh auth, repo creation, Pages enablement,
   and the first deploy watch — requires the `gh` CLI.)
```

If `K > 0`, append:

```
  Open review.md, set approved: true on flags to apply, then re-run /tmb:review.
```

If the server didn't start, append:

```
If the server didn't start automatically:
  cd <target> && ./serve.sh
  (then open http://localhost:1313)
```

## Why this is a separate file

The skill's main workflow doesn't need to carry 60 lines of tmux invocation, readiness logic, and the printed block — the Phase 10/11 reader needs that detail, but Phases 0-9 don't. Keeping the SKILL slim helps the agent pick the skill confidently and run earlier phases without scrolling past the delivery scaffold.
