# Quality gates — `/tmb:create`

Loaded at the very end of `/tmb:create`, before declaring delivery complete. The orchestrator should have a green check on every line below; if any is red, the delivery block lies.

- [ ] `check-deps.sh` passed (Phase 0)
- [ ] All 7 interview steps confirmed
- [ ] Target directory was `fresh` or `v0.4-partial`
- [ ] `research.yaml` written; `validate-research.sh` passed
- [ ] `curriculum_spine.md` and every `briefs/NN-slug.yaml` written; `validate-briefs.sh` passed
- [ ] Hugo site scaffolded (`scaffold-site.sh` exited 0)
- [ ] `new-module.sh` succeeded for every brief (frontmatter populated, exercises/ created, VALIDATION.md + new_terms.yaml seeded)
- [ ] Every module-builder returned (success, or failure flagged for the reviewer)
- [ ] `review.md` written
- [ ] `./build.sh` succeeded; `site/public/` exists
- [ ] Server is running OR user has the exact `serve.sh` invocation
- [ ] Delivery block printed with accurate runtime state (matches whether tmux serve succeeded)

If a gate is red, the right action is almost always to surface the specific failure to the user rather than papering over it. The pipeline is designed so that *any* downstream agent can be re-dispatched after a failure — the user can re-run `/tmb:review` after fixing review.md flags, or re-run `/tmb:add-module` after a builder timeout.
