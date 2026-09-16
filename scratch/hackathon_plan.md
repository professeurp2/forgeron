# Group Memory Bot — Execution Plan
**UniPods METI AI Hackathon · Cohort 1**
Team lead: Lamine SACKO (Mali) · Build window: **Fri 18 → Thu 24 Sept 2026** · Prize: $5,000

> **Rule that governs everything:** ship a thin end-to-end slice on Day 1 and keep it deployed.
> A bot the judges can message beats a better bot that only runs on a laptop.

---

# PHASE 0 — Before the clock starts

## D-2 · Wednesday 16 Sept (TODAY) — build the team

| # | Task | Owner | Done when |
|---|---|---|---|
| 0.1 | Post the recruitment message in the cohort group | Lamine | Message posted |
| 0.2 | Collect candidates in DM; confirm **≥1 woman** and **≥2 countries** | Lamine | Constraints satisfied |
| 0.3 | Pick a team name | All | Name agreed |
| 0.4 | Assign roles (see §Roles) | Lamine | Each role has an owner |
| 0.5 | Create the WhatsApp/Telegram team group | Lamine | Everyone in |

> ⚠️ **The two eligibility rules are hard blockers.** A team that is all-Malian, or all-male, is disqualified regardless of how good the bot is. Confirm both **before** sending the email.

## D-1 · Thursday 17 Sept — declare + set up

**🚨 Team declaration email is due CLOSE OF BUSINESS TODAY.** Subject: `UniPods Hackathon`. Include every member and their country of origin.

| # | Task | Owner | Done when |
|---|---|---|---|
| 1.1 | **Send the declaration email** | Lamine | Sent, with members + countries |
| 1.2 | Create the public GitHub repo + invite the team | Lamine | Everyone can push |
| 1.3 | Get a **Gemini API key** (each member gets their own → quota pooling) | All | Keys in hand |
| 1.4 | Create the **Supabase** project, enable `pgvector` | Backend | `vector` extension enabled |
| 1.5 | Create a **Telegram bot** via @BotFather + a test group | Integration | Token in hand |
| 1.6 | Create the hosting account (Railway/Render) | Integration | Account ready |
| 1.7 | **Export the WhatsApp cohort chat** (`Export chat → without media`) | Lamine | `.txt` file saved |
| 1.8 | Collect 1–2 **call recordings** for testing | Product | Files saved |
| 1.9 | 45-min kickoff call: walk the spec, lock decisions (§Decisions) | All | Decisions written in the repo |

### ⚙️ Decisions to lock on D-1 (changing these later costs a re-index)

| Decision | Default | Why it matters |
|---|---|---|
| **Embedding model + dimension** | `text-embedding-004` (768) **or** `paraphrase-multilingual-MiniLM-L12-v2` (384) | Must be **the same** for indexing and querying, and must match the `vector(n)` column |
| Primary adapter for the demo | Telegram (safe) | WhatsApp group reading is not supported by the official API |
| History source | WhatsApp export `.txt` | The reliable path to the backlog |
| LLM | Gemini Flash / Flash-Lite | Free tier, function calling |
| Language of answers | Match the question (EN/FR) | Cohort is bilingual |

---

# PHASE 1 — The build (7 days)

## Working rhythm (team is spread across countries)

- **Daily async standup** (written, in the team group, by 09:00 each member's time): *done / doing / blocked*.
- **One 30-min live sync per day** at a fixed UTC time.
- **End of every day: deploy.** The `main` branch is always live.
- Branch per task → PR → quick review → merge. No direct pushes to `main`.

---

## 🗓️ DAY 1 · Friday 18 — skeleton live

**Objective:** an empty but *deployed* bot that answers "pong" in a real group.

| # | Task | Owner | Acceptance criteria |
|---|---|---|---|
| D1.1 | Repo scaffold (`app/`, `requirements.txt`, `.env.example`, README stub) | Lead | `pip install -r requirements.txt` works on a clean machine |
| D1.2 | FastAPI app + `/health` endpoint | Backend | `GET /health` → `{"status":"ok"}` |
| D1.3 | Telegram adapter: receive message → reply | Integration | Bot replies in the test group |
| D1.4 | Deploy to Railway/Render from GitHub | Integration | Public URL live; webhook set |
| D1.5 | Supabase schema v1 (`documents`, `chunks`, `embedding vector(n)`) | Backend | Tables created; a row inserts |
| D1.6 | Parse the WhatsApp export → count messages (no DB yet) | Data | Script prints N messages parsed |
| D1.7 | Test question set: 20 real questions + expected answers | Product/QA | File `tests/questions.md` committed |

**✅ End of Day 1:** a judge could message the bot and get *something* back, from a URL that isn't your laptop.

---

## 🗓️ DAY 2 · Saturday 19 — ingestion

**Objective:** the whole chat history is in the database, chunked and embedded.

| # | Task | Owner | Acceptance criteria |
|---|---|---|---|
| D2.1 | WhatsApp export parser → normalised records (author, ts, text) | Data | Handles multi-line messages, system messages, attachments-omitted |
| D2.2 | Chunking (group consecutive messages into ~300–500 token windows, keep metadata) | Data | Chunks carry author, date range, source |
| D2.3 | `embeddings.py` with **both providers** + one switch | Lead | Same dimension both ways; unit test passes |
| D2.4 | Bulk indexer script (`scripts/ingest_chat.py`) | Backend | Full history indexed; row count matches |
| D2.5 | Vector index in Postgres (ivfflat/HNSW) | Backend | Similarity query returns in < 500 ms |
| D2.6 | Live message ingestion (new messages get indexed) | Integration | New test message is searchable within 1 min |

> 💡 Run the **bulk indexing locally** with `sentence-transformers` — thousands of messages would burn the API quota.

**✅ End of Day 2:** `SELECT` a semantic query, get relevant real messages back.

---

## 🗓️ DAY 3 · Sunday 20 — the core: grounded answers

**Objective:** the bot answers real questions, with sources. **This is the day that decides the project.**

| # | Task | Owner | Acceptance criteria |
|---|---|---|---|
| D3.1 | Retrieval: top-k semantic + recency boost | Lead | Returns the right chunk for 15/20 test questions |
| D3.2 | Answer prompt: grounded, cites sources, refuses when unsupported | Lead | Never answers from outside the context |
| D3.3 | Citation formatting (author + date + quote/link) | Lead | Every answer shows where it came from |
| D3.4 | Wire answering into the adapter (mention + DM) | Integration | Ask in the group → answer in the group |
| D3.5 | Run the 20-question test set, record the score | QA | Score written in `tests/RESULTS.md` |

**✅ End of Day 3 — GO/NO-GO checkpoint:** if the bot can't answer a real question with a source, **stop adding features** and fix this. Everything else is worthless without it.

---

## 🗓️ DAY 4 · Monday 21 — calls

**Objective:** what was said in a meeting is answerable too.

| # | Task | Owner | Acceptance criteria |
|---|---|---|---|
| D4.1 | Transcription pipeline (faster-whisper) | Audio | A 30-min recording → transcript with timestamps |
| D4.2 | Speaker segmentation *(if cheap; otherwise skip)* | Audio | Optional |
| D4.3 | Transcript → chunks → same index, `source=call` | Data | Call content appears in search |
| D4.4 | Upload path: send the bot a file/link → it ingests | Integration | Bot confirms "recording indexed" |
| D4.5 | Test: 5 questions answerable **only** from the call | QA | 4/5 correct |

**✅ End of Day 4:** ask about something only said out loud in a meeting → correct answer.

---

## 🗓️ DAY 5 · Tuesday 22 — 🔒 MVP FREEZE + the winning features

**Objective:** R1–R8 complete and deployed. **No new scope after today.**

| # | Task | Owner | Acceptance criteria |
|---|---|---|---|
| D5.1 | **Duplicate detection**: new question similar to an answered one → "already covered here" + link | Lead | Triggers on a real repeat question |
| D5.2 | **`/catchup`**: summary since a date (default: 7 days) | Backend | Returns threads, decisions, deadlines |
| D5.3 | Rate limiting per user + answer cache | Backend | No quota blow-up under load |
| D5.4 | LLM fallback (second key / second model on 429) | Lead | Forced 429 → still answers |
| D5.5 | Re-run the full test set | QA | Score ≥ Day 3, no regression |

**✅ End of Day 5:** feature-complete MVP, live. From here it's polish only.

---

## 🗓️ DAY 6 · Wednesday 23 — polish & harden

**Objective:** it doesn't break in front of 244 people.

| # | Task | Owner | Acceptance criteria |
|---|---|---|---|
| D6.1 | **Meeting recap**: summary + decisions + action items per recording | Lead | Readable recap for a real call |
| D6.2 | **Daily digest** (scheduled job) | Backend | Posts once at a fixed hour |
| D6.3 | Error handling: no crash on any input (empty, emoji, huge, wrong file) | Backend | Fuzz test passes |
| D6.4 | Load test: 20 questions in 1 min | QA | No timeout, no crash |
| D6.5 | Privacy pass: document what's stored; add an index-wipe command | Lead | Written in README |
| D6.6 | Logging/monitoring (so you can see failures during judging) | Integration | Logs visible |

**✅ End of Day 6:** stable under abuse. Nothing left to build.

---

## 🗓️ DAY 7 · Thursday 24 — package & submit

**Objective:** submitted early, with a demo you've rehearsed.

| # | Task | Owner | Acceptance criteria |
|---|---|---|---|
| D7.1 | **README / setup notes** (required deliverable) | Docs | A stranger clones and runs it in < 15 min |
| D7.2 | Clean the repo (no secrets, `.env.example` complete, license) | Lead | `git grep` finds no API key |
| D7.3 | **2-min demo video** | Product | Shows the 6 demo beats (§Demo) |
| D7.4 | **Full dry run of the demo**, twice | All | No surprises |
| D7.5 | Backup plan: recorded demo + screenshots if live fails | Product | Files ready |
| D7.6 | **Submit** (working bot + repo + setup notes) | Lamine | Confirmation received |

> ⏰ **Submit in the morning, not at midnight.** Leave a buffer for one thing going wrong.

---

# Roles

| Role | Owner | Responsibility |
|---|---|---|
| **Team lead / AI** | Lamine | Architecture, RAG, prompts, final demo |
| **Backend / data** | ⟦ ⟧ | Parser, schema, indexing, jobs |
| **Integration / DevOps** | ⟦ ⟧ | Adapter, deployment, uptime, logs |
| **Audio / ML** | ⟦ ⟧ | Transcription pipeline |
| **Product / QA / docs** | ⟦ ⟧ | Test questions, README, video, demo script |

*Fewer than 5 people? Merge roles — but **never** leave deployment or documentation unowned.*

---

# Parallel tracks (so nobody is blocked)

```
Track A (Lead)        : embeddings → retrieval → prompts → dedup
Track B (Backend/Data): parser → schema → indexing → digest jobs
Track C (Integration) : adapter → deploy → live ingestion → monitoring
Track D (Audio)       : transcription → transcript chunks
Track E (QA/Docs)     : test set → runs → README → video
```
Only hard dependency: **Track A needs the schema from Track B (Day 2 morning)**. Agree the table shape on Day 1 so both can move.

---

# Risk checkpoints

| When | Check | If it fails |
|---|---|---|
| D1 EOD | Bot deployed & replying | Drop the fancy adapter, use the simplest one that works |
| D3 EOD | Grounded answers on real questions | **Freeze all other work**; this is the product |
| D4 EOD | Call transcript answerable | Ship chats-only; allow manual transcript upload |
| D5 EOD | MVP complete | Cut every nice-to-have without discussion |
| D6 EOD | Stable under load | Cut features until it is |

---

# Demo script (5 min, rehearsed)

1. **The pain in one line** — "someone asked a question that had already been answered three times."
2. A judge asks a **real question** → grounded answer **with source**.
3. *"What did I miss this week?"* → digest.
4. A question answerable **only from a call** → answer from the transcript.
5. **Re-ask an old question** → "this was already covered here" + link.
6. Show the **repo + README**, and state it is deployed and running right now.

---

# What makes this win

- It **runs live** and the judges can try it themselves.
- Answers are **sourced** — trust is the whole game.
- It solves **their** pain (repeats, missed calls), not a generic chatbot demo.
- The WhatsApp API limitation is **handled openly**, with an architecture that survives it.
- Anyone can **clone and run it**.
