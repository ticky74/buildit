# buildit — Agentic Business Process Execution

> **From legacy knowledge to working agents.**
>
> buildit takes business process knowledge (extracted by ibah) and turns it
> into conversational agents that execute those processes. No forms. No CRUD.
> No GraphQL endpoints. Just agents that know how to do the job.

---

## Vision

Every company has business processes trapped in legacy code, tribal knowledge,
and manual workflows. ibah extracts that knowledge into structured execution
paths. buildit consumes those execution paths and creates agents that can
execute the processes through natural conversation.

**The first agent: Site Supervisor** — a virtual site manager that handles
production workflows. Starting with VPOR (Vendor Purchase Order Request)
creation, the process that happens hundreds of times a day when vendors call
in requesting work.

### The Demo

A vendor calls and says: *"I need to create a VPOR for Acme Corp, $15,000
for consulting services."*

The Site Supervisor agent:
1. Queries ibah for the VPOR creation execution path
2. Follows the steps: validates the vendor, checks authorization, gathers
   required fields through conversation
3. Creates the VPOR record
4. Routes it for approval
5. Confirms completion

No forms filled out. No screens navigated. Just a conversation that gets
the job done.

---

## Core Principles

### 1. Agentic First

Every feature is designed for agent consumption, not human point-and-click.
Interfaces are voice, chat, sensors, and media — not forms and buttons.
When humans need to review data (dashboards, reports), the agent prepares
and presents it.

### 2. Schema Emerges from Knowledge

No hand-coded database schemas. The execution paths define the data shapes.
The agent reads `input_shape`, `state_changes`, and `steps[].dataAccess`
from ibah and derives what data it needs to store and retrieve. When the
business process changes, the execution path gets updated, and the agent
adapts. No migrations.

### 3. Knowledge-Driven, Not Code-Driven

The agent doesn't contain hardcoded business logic. It reads execution paths
from ibah at runtime. The ibah knowledge base IS the specification. When
knowledge improves (new paths captured, old paths deprecated), the agent
immediately benefits.

### 4. Processes, Not Endpoints

The business speaks in outcomes and processes:
- Outcome: "Vendors get paid on time"
- Process: "VPOR Lifecycle"
- Execution paths: Create, Submit, Approve, Process Payment, Report

We build agents that execute processes, not APIs that expose data operations.

---

## Architecture (Intentionally Minimal)

```
                    ibah Knowledge Base
                    (execution paths, business rules,
                     domain entities, state machines)
                          |
                          | ibah MCP (ibah-query, ibah-search)
                          v
                 ┌─────────────────┐
                 │  buildit Agent   │
                 │  "Site Supervisor"│
                 │                  │
                 │  Reads playbooks │
                 │  Executes steps  │
                 │  Manages state   │
                 │  Talks to humans │
                 └────────┬────────┘
                          |
              ┌───────────┼───────────┐
              v           v           v
         Voice/Chat    Sensors     Other Agents
         (human i/o)   (IoT/data)  (delegation)
```

**No tech stack decisions yet.** We'll make those as we build, driven by
what the agent actually needs — not by what's fashionable.

---

## Two Phases

### Phase 1: The Agent

Build a multi-turn conversational agent that can execute the VPOR creation
workflow. The agent:
- Connects to ibah to read execution path knowledge
- Conducts a multi-turn conversation to gather required information
- Validates inputs against business rules (from ibah)
- Executes the process steps
- Handles errors and edge cases as defined in the execution paths
- Reports completion

**Starting scope:** One process — "Create and Submit VPOR." Enough to prove
the pattern. Approval, payment, and reporting follow incrementally.

### Phase 2: The Backend

Build whatever operational infrastructure the agent needs to do its job.
This is explicitly "work to be done" — not the interesting part. The agent
tells us what it needs (data storage, external integrations, notification
channels), and we build it. Claude Coder handles most of this.

---

## The Bigger Picture

The Site Supervisor starts with VPORs but eventually handles all production
workflows on a construction site. It becomes a virtual site manager —
fielding requests, coordinating vendors, tracking approvals, managing
compliance, reporting to project managers.

And it all starts with: *"I need to create a VPOR."*

---

## ibah Connection

This project depends on ibah (the Archeologist Series) for all business
process knowledge. ibah extracts execution paths from legacy code and
delivers them via MCP tools.

- **ibah server:** http://localhost:3100 (dev)
- **ibah MCP tools:** ibah-search, ibah-query, ibah-capture-path
- **Target project:** The VPOR knowledge already extracted in ibah

The agent does NOT contain business logic. It reads it from ibah at runtime.

---

## Conventions

- No tech stack locked in yet — choices made as needed
- Commits: `feat:`, `fix:`, `chore:` prefix + Co-Authored-By
- Tests: written as we build, covering agent behavior not implementation
- This file evolves as the project takes shape

---

**Document Status:** Genesis
**Created:** 2026-02-20
