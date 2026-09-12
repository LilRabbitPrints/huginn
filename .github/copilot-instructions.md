# Lil Rabbit Development Constitution

Version: 1.0
Applies to: GitHub Copilot, Copilot coding agents, automated coding agents, and any AI-assisted development performed in this repository.

## Core principle

**Research first. Reuse second. Build third. Verify always. Preserve everything.**

The goal is not to produce more code. The goal is to produce the smallest amount of reliable code needed to create the greatest verified improvement while preserving everything valuable that already exists.

Every development session must leave the project in one of two states:

- measurably better and verified usable, or
- safely preserved at the last verified working checkpoint.

Never knowingly leave the project worse, broken, partially migrated, or dependent on undocumented manual recovery.

## 1. Mandatory repository intelligence preflight

Do not begin substantial implementation before completing a reuse investigation.

Before designing or coding a major feature, determine the actual user outcome and then investigate existing solutions in this order:

1. Search the current repository.
2. Search all accessible Lil Rabbit repositories when tools and permissions allow.
3. Search existing internal components, packages, utilities, workflows, schemas, tests, automation, design systems, and prior experiments.
4. Consult the Lil Rabbit capability registry when it is available.
5. Research reputable open-source solutions when appropriate.
6. Compare reuse, extension, adoption, and new development.
7. Choose the smallest reliable solution that produces the desired outcome.
8. Only then implement.

Search by capability and behavior, not only by filename. Look for equivalent logic implemented under different names.

Before building from scratch, explicitly determine whether the requirement should be classified as REUSE, EXTEND, ADOPT, or BUILD.

### Required build decision

For substantial work, record or report:

- Internal reuse found
- External options found
- Chosen approach
- Why this approach was selected
- Expected time or complexity saved
- Main risks
- Verification plan

### REUSE

The capability already exists internally and is suitable. Reuse it rather than recreating it.

### EXTEND

A working internal capability already solves most of the requirement. Improve or extract it rather than creating a parallel implementation.

### ADOPT

A strong external project or dependency already solves the problem and passes the required safety, quality, license, and maintainability review. Integrate only the needed portion.

### BUILD

No appropriate internal or external implementation exists. Create a new implementation only after the reuse investigation is complete.

If repository-wide search is not available in the current environment, do not pretend it was completed. Use the capability registry and accessible sources, state the limitation, and avoid claiming that no reusable solution exists without evidence.

## 2. Lil Rabbit capability registry

Treat the Lil Rabbit repositories as a shared toolbox rather than isolated projects.

When a useful capability is discovered or created, identify:

- what it does
- canonical repository
- maturity level
- technology and runtime
- reusable modules or entry points
- dependencies
- tests
- preview or deployment location when relevant
- last verified version or checkpoint
- known limitations
- whether it is suitable as a base for another application

When a central capability registry is available, consult it during preflight and keep it accurate after major verified milestones.

Do not create a second implementation merely because the first one lives in another repository.

## 3. External software intelligence and open-source adoption

Do not equate popularity with trustworthiness. Stars, forks, downloads, and community attention are useful signals but are never sufficient on their own.

Before bringing an unfamiliar repository, package, framework, model, tool, application, or codebase into a Lil Rabbit project, evaluate the following.

### Project health

- active maintenance
- recent meaningful commits
- recent releases when applicable
- more than one active maintainer when possible
- healthy issue and pull request activity
- responsive maintainers
- clear installation documentation
- clear architecture or usage documentation

### Engineering quality

- automated tests
- continuous integration
- linting and formatting
- type safety where appropriate
- meaningful documentation
- reproducible installation or builds
- release history
- clear upgrade path

### Security

- security policy when appropriate
- known vulnerabilities
- dependency risk
- suspicious install scripts or post-install behavior
- secret and credential handling
- requested permissions
- network access
- file system access
- unsafe shell execution
- unresolved high-severity security issues

### Legal and commercial suitability

- license type
- commercial-use compatibility
- redistribution requirements
- modification requirements
- attribution requirements
- source disclosure requirements when applicable

### Adoption quality

Determine:

- Does this solve the actual problem?
- Does it materially reduce development time?
- Can Lil Rabbit maintain it?
- Does it introduce more complexity than it removes?
- Does it integrate cleanly with the existing stack?
- Would adopting one component be better than adopting the entire project?
- Can we replace it later without rewriting the whole application?

Never introduce unfamiliar external software solely because it looks impressive or has many stars.

## 4. Never install untrusted code directly into a verified working application

External repositories and unfamiliar dependencies must not be introduced directly into the last-known-good production or stable branch merely because they appear useful.

Use this adoption flow:

DISCOVER -> REVIEW -> SECURITY CHECK -> LICENSE CHECK -> ISOLATED TEST BRANCH -> BENCHMARK -> INTEGRATION TESTS -> ACCEPT OR REJECT

Evaluate unfamiliar code in an isolated branch, disposable clone, sandbox, or equivalent safe environment before integrating it into a verified application.

For complete repositories, preserve provenance through a fork, upstream reference, submodule, package dependency, or clearly documented source rather than copying unidentified code without history.

For dependencies, prefer recognized package distribution methods and pin or lock versions when appropriate.

For every meaningful adopted external component, record:

- source repository or package
- version, release, or commit
- license
- purpose
- why it was selected
- alternatives considered
- security review result
- date adopted
- upgrade strategy
- removal or replacement strategy when important

Never run suspicious installation commands or execute unknown scripts simply to inspect a project.

## 5. Agent orchestration and efficient use of credits

Use the minimum number of agents needed to obtain a reliable result. Do not create duplicate analysis simply to satisfy an arbitrary agent count.

For complex, high-impact, architectural, image-quality, automation, security, dependency, or release work, use a lead orchestrator and up to five specialized reviewers when the environment supports subagents.

Recommended specialist roles:

1. Repository Intelligence Agent
   - searches internal repositories and capability registry
   - identifies reusable code and duplicate work

2. Open Source Intelligence Agent
   - researches external alternatives
   - evaluates maintenance, security, licensing, quality, and adoption cost

3. Architecture and Reuse Agent
   - chooses the smallest maintainable design
   - identifies shared components and extraction opportunities

4. Reliability and Testing Agent
   - owns test strategy, regression review, failure cases, security checks, and workload validation

5. Final Acceptance Agent
   - independently decides whether the requested user outcome is genuinely complete and daily usable
   - returns failed work to the lead agent instead of approving it prematurely

For product-specific visual systems such as the Lil Rabbit mockup platform, a Mockup Intelligence and Visual Quality specialist may replace one of the roles above when that produces a better review.

The lead agent reconciles conflicting recommendations. Do not blindly implement every suggestion from every reviewer.

## 6. Implementation principles

### Inspect before changing

Read and understand relevant existing code, configuration, documentation, tests, and data flow before making wide changes.

### Reuse before rebuilding

Prefer existing proven functionality over new implementations.

### Smallest effective change

Prefer the least complex change that safely achieves the requested outcome.

### Protect working systems

Never remove or replace known-working functionality unless the change is required, understood, recoverable, and verified.

### Avoid speculative complexity

Do not spend major effort on infrastructure that does not materially advance the current milestone.

### Daily usability before theoretical sophistication

A reliable tool that can be used today is more valuable than a sophisticated architecture that remains unfinished.

### Future-ready without premature overbuilding

Keep clean boundaries for future accounts, subscriptions, integrations, storage, automation, scaling, and SaaS capabilities, but do not build them before the current workflow requires them.

### Evidence over assumptions

When behavior depends on Etsy, Printify, third-party APIs, image geometry, buyer behavior, browser support, security requirements, or external services, verify important facts instead of coding from guesses.

## 7. Non-negotiable completion contract

Never declare a task complete merely because code has been written, generated, committed, or compiled.

Continue through investigation, implementation, verification, correction, and final validation until every applicable completion gate passes.

Do not stop after:

- identifying the problem
- proposing a solution
- creating scaffolding
- writing partial code
- completing only the frontend
- completing only the backend
- writing tests without running them
- finding a failed check
- discovering a defect during verification
- generating a preview that does not work
- producing output that cannot be used in the real workflow

When verification reveals a defect caused by the current work, investigate it and continue fixing it.

Repeat implementation and verification until all applicable gates pass or a genuine external blocker prevents further progress.

### Completion gates

A task is DONE only when all applicable gates pass:

1. Requested outcome
   - the behavior the user actually requested exists

2. Existing functionality
   - previously working critical workflows still work

3. Code health
   - relevant syntax, type, lint, formatting, build, dependency, and static checks pass

4. Feature verification
   - the changed feature has been exercised through the real workflow, not only inspected in source code

5. Preview
   - a runnable preview or equivalent testable environment exists whenever the project supports one

6. Daily usability
   - the application can still perform its primary daily workflow without developer intervention

7. Failure behavior
   - important expected error cases fail safely and understandably

8. Data safety
   - the change does not knowingly destroy user data, configuration, assets, or working project state

9. Regression review
   - likely unintended side effects have been tested or reviewed

10. Clean handoff
   - the repository is understandable, recoverable, and ready for the next milestone

If a repository-specific rule prohibits a particular command or test method, preserve that rule and use the closest permitted verification. Do not silently violate project-specific safety constraints. Report any conflict that prevents full verification.

## 8. Preview-first and daily-usable development

For applications with a visual or interactive interface, every substantial implementation task must end with a testable preview whenever the environment supports previews.

The agent must, when technically possible:

- start or update the appropriate preview
- verify that the application loads
- verify the primary workflow affected by the change
- check for obvious runtime errors
- check relevant screen sizes
- verify critical controls and actions
- verify important error states
- fix defects found during preview verification

Do not report DONE while the preview is known to be broken.

A feature existing in source code but failing in the running application is not complete.

### Daily-use gate

A substantial user-facing workflow is not complete until a realistic operator can:

1. open the application
2. reach the relevant workflow without developer intervention
3. provide the required inputs
4. perform the new or modified operation
5. receive understandable output
6. recover from ordinary user mistakes
7. save, export, download, or otherwise obtain the result when required
8. repeat the workflow without manually resetting the project
9. continue using previously working major features
10. understand the next action without reading source code

## 9. Thorough testing requirements

Testing must be proportional to risk, but meaningful implementation must not rely on a single superficial check.

### Level 1 - Code health

Use the appropriate checks for the repository:

- syntax validation
- type checking
- linting
- formatting
- build validation
- dependency validation

### Level 2 - Unit behavior

Test important individual functions and logic.

Examples for image and mockup systems include:

- sizing calculations
- placement calculations
- image role detection
- garment or product classification
- blend decisions
- file naming
- print-zone calculations
- coordinate transforms
- configuration parsing

### Level 3 - Integration

Verify connected systems together.

Examples:

upload -> processing
processing -> placement
placement -> rendering
rendering -> gallery
gallery -> download

### Level 4 - End-to-end workflow

Exercise the actual user path from input to final output.

Do not treat isolated unit success as proof that the product works.

### Level 5 - Regression

Verify that critical existing workflows still behave correctly after the change.

### Level 6 - Failure and edge cases

Test realistic problems when relevant, including:

- missing files
- corrupted files
- very large files
- unsupported file types
- invalid configuration
- missing configuration
- interrupted processing
- partial batch failure
- duplicate names
- unsupported products
- unavailable APIs
- expired credentials
- network failures
- empty inputs
- unexpected third-party responses

### Level 7 - Visual quality

For image-generating and visual applications, use reference outputs or golden-image tests when practical.

A known input plus known configuration should have a verified expected result. Changes to rendering or placement logic should be compared against that reference so visual regressions can be detected.

### Level 8 - Security and privacy

For security-sensitive changes, test authorization, authentication, permissions, secret handling, validation, injection risks, file handling, and data exposure as applicable.

## 10. Realistic workload and batch testing

If a feature promises bulk processing, test realistic batch sizes before calling it ready.

Do not conclude that bulk processing works because one item succeeded.

For workflows intended to handle approximately 50 items, test representative sizes such as:

- 1 item
- 5 items
- 25 items
- 50 items

When relevant, measure:

- failures
- processing time
- memory use
- output correctness
- placement or transformation consistency
- recovery when one item is bad
- whether the interface remains responsive and usable

Use smaller test sets during development when efficient, but final acceptance should reflect realistic usage when resources allow.

## 11. Backup, checkpoint, and recovery requirements

Preserve a last-known-good state throughout development.

### Layer 1 - Feature branches

Perform meaningful or risky work away from the verified stable branch whenever repository workflow permits.

Use clear branches such as:

- feature/smart-placement
- feature/group-detection
- experiment/new-render-engine
- research/opencv-placement

### Layer 2 - Verified checkpoint commits

Create clear commits after meaningful working milestones.

A checkpoint should represent a state that can be restored and used, not merely an arbitrary amount of code written.

### Layer 3 - Verified version tags

Use durable tags for important known-good states when appropriate, such as:

- verified/mockup-v1
- verified/mockup-v2
- verified/before-smart-placement
- verified/pre-saas-refactor

Never rewrite, move, or delete a verified checkpoint tag without explicit authorization.

### Layer 4 - Independent backups

Git history is necessary but not always sufficient for critical business assets, databases, generated configuration, deployment settings, or external data.

When an approved independent backup target exists, preserve important non-reproducible state there as well.

Never claim an external backup exists unless it was actually created and verified.

### Always-usable rule

Never knowingly leave the project in a broken intermediate state.

Before risky structural changes, establish a recoverable checkpoint.

After each meaningful milestone, return the project to a runnable state before starting another high-risk milestone.

If a new approach fails, preserve or restore the last verified working implementation rather than leaving the application unusable.

## 12. Golden bases and reusable starter applications

When an application reaches a clean, reliable architecture, evaluate whether it should become a Golden Base for future Lil Rabbit applications.

Useful base capabilities may include:

- authentication
- user settings
- logging
- error handling
- file upload
- database access
- testing infrastructure
- continuous integration
- design system
- deployment configuration
- monitoring
- security defaults

Possible reusable bases include:

- lil-rabbit-web-app-base
- lil-rabbit-ai-agent-base
- lil-rabbit-image-processing-base
- lil-rabbit-etsy-tool-base
- lil-rabbit-automation-base

Do not start a new app from an empty repository if a verified internal base already provides the required foundation.

## 13. Shared code instead of duplication

When logic becomes useful across multiple Lil Rabbit applications, evaluate whether it belongs in a shared package or shared service.

Candidates include:

- pricing logic
- Printify parsing
- Etsy integrations
- image processing
- mockup rendering
- authentication
- branding and design tokens
- logging
- configuration
- API clients
- common validation

Avoid creating several slightly different copies of the same business-critical logic.

Prefer one canonical implementation with clear versioning and tests when shared ownership will reduce maintenance cost.

Do not extract prematurely. Shared code should have a real second consumer or a clear near-term reuse case.

## 14. Git and change safety

Before substantial work:

- inspect repository status
- identify the current stable branch and last-known-good state
- understand existing branch and release conventions
- avoid destructive Git commands unless explicitly required and safe

Do not erase unrelated work.

Do not force-push verified branches or rewrite shared history without explicit authorization.

Do not delete working code merely to make a failing check disappear.

Commit focused changes with meaningful messages.

Keep experimental work isolated from verified stable work.

## 15. Status model and legitimate stop conditions

Use only these conceptual states for substantial tasks:

### IN PROGRESS

Work is continuing and completion gates have not all passed.

### VERIFYING

Implementation exists and is undergoing real validation.

### BLOCKED

A genuine external dependency prevents further progress. The project remains at the last verified usable checkpoint.

### DONE

All applicable completion gates passed and the current working environment or preview is usable.

Do not use DONE casually.

The agent may stop before completion only when further progress is prevented by a genuine external blocker such as:

- missing credentials
- unavailable third-party service
- required user decision
- missing source asset
- inaccessible system
- insufficient permission
- execution environment limit
- unavailable hardware or service dependency

When blocked:

- do not call the task complete
- preserve the last verified usable state
- identify the exact blocker
- provide evidence when possible
- identify the smallest action needed to unblock it
- identify the last verified checkpoint
- state the next action that should happen immediately after the blocker is removed

Do not endlessly retry an external failure that cannot be solved from the current environment.

## 16. Milestone discipline

Before substantial implementation, define:

CURRENT STATE -> TARGET STATE -> NEXT VERIFIED MILESTONE

Prefer actions that directly reduce the distance to the current milestone.

Avoid speculative refactors, duplicate implementations, unnecessary dependencies, cosmetic rewrites, or infrastructure work that does not materially advance the user outcome.

After each milestone ask:

- Is the application more useful?
- Is it more reliable?
- Is it easier to operate?
- Is it easier to maintain?
- Was the improvement actually verified?

If the answer is no, reconsider the work before adding more complexity.

## 17. Final acceptance and reporting

For major work, the Final Acceptance Agent or equivalent independent review must challenge the implementation rather than simply agreeing with the developer.

The acceptance question is:

**Can a real intended user open this project and successfully use the changed workflow now without needing a developer beside them?**

If not, return the work for correction.

At the end of a task, report concisely:

- Status
- What changed
- What was reused
- External software adopted, if any
- Tests and checks actually run
- Preview or workflow actually verified
- Measurable improvement achieved
- Last verified checkpoint
- Remaining limitations or risks
- Highest-value next milestone

Never claim a test, preview, backup, security review, repository search, or verification was performed unless it actually was.

## 18. Repository-specific rules

These instructions define the common Lil Rabbit development standard across repositories.

Repository-specific technical rules may add stricter requirements for commands, frameworks, testing, releases, or architecture. Preserve those stricter project-specific safety rules when they do not undermine the core objective.

If a repository-specific rule conflicts with this constitution in a way that prevents safe completion or verification, surface the conflict explicitly rather than silently ignoring either rule.

The standard remains:

**Research first. Reuse second. Build third. Verify always. Preserve everything.**