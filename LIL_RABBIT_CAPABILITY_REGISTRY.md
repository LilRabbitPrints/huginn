# Lil Rabbit Capability Registry

Canonical owner: `LilRabbitPrints/lil-rabbit-growth-hq`
Last synchronized: 2026-09-12

## Purpose
This is the cross-repository map for Lil Rabbit Prints and Lil Rabbit Labs. Read it before substantial design or implementation work so existing capabilities are reused before new code is created. Verify current code, tests, and last-known-good state before reuse.

## Reuse priority
1. REUSE verified internal capability.
2. EXTEND strong internal capability.
3. ADOPT a well-vetted external component.
4. BUILD only when the first three are insufficient.
Never create a parallel implementation merely because the existing capability lives in another repository.

## Repository inventory
- `lil-rabbit-mockup-generator`: strongest current internal mockup/image-processing candidate; documented bulk engine, Flask UI, placement zones, blend modes, group mockups, tuning, upload, progress, gallery, ZIP export, and batch failure handling. Audit before rebuilding and runtime-verify before Golden Base status.
- `lil-rabbit-mockup-platform`: private Mockup Studio shell. Do not rebuild generator capabilities here before a reuse/migration decision.
- `lil-rabbit-growth-hq`: canonical growth planning, approvals, evidence, handoffs, coordination, and quality-gate workspace.
- `lil-rabbit-products-pricing`: canonical product, Printify, cost, pricing, profit, collection, and fulfillment planning workspace.
- `lil-rabbit-listing-seo`: canonical Etsy search, listing-copy, keyword-evidence, and listing-package workspace.
- `lil-rabbit-design-studio`: canonical design-system, creative manifests, placement standards, listing-image and visual-quality workspace.
- `lil-rabbit-marketing-growth`: canonical campaigns, Pinterest, social, AI-video, traffic, retention, and conversion-learning workspace.
- `prime-agent-tester`: agent-orchestration and long-running-agent research base. Treat as agent-platform research, not the mockup product.
- `huginn`: external/upstream automation-engine research base. ADOPT/RESEARCH only after maintenance, license, dependency, security, and deployment review.
- `i-have-adhd`: external/upstream assistant communication/output-format skill. Preserve provenance and license.

## Cross-repository duplication rules
Before creating a capability, search this registry and inspect likely repositories by behavior, architecture, and data model. If similar implementations exist, choose the strongest verified version, declare one canonical owner, extract or migrate reusable logic when worthwhile, avoid drifting copies, and preserve history/provenance.

## Golden Base rules
A checkpoint may be a Golden Base only after primary workflows run, required tests pass, realistic failures are handled, runtime/preview is verified when applicable, operational documentation is sufficient, secrets are not embedded, dependencies/licenses are understood, and a recoverable tag/checkpoint exists.

Potential future bases: `lil-rabbit-web-app-base`, `lil-rabbit-ai-agent-base`, `lil-rabbit-image-processing-base`, `lil-rabbit-etsy-tool-base`, `lil-rabbit-automation-base`.

## Registry maintenance
After major verified milestones update capability, canonical repository, maturity, reusable entry points, tests, preview/deployment when appropriate, last verified commit/tag, known limitations, and Golden Base suitability. If cross-repository access is unavailable, use this local copy and state that freshness was not independently verified.