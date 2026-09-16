# Group Memory Bot — Technical Specification
**UniPods METI AI Innovation Programme · Cohort 1 — Chatbot Hackathon**
Team lead: Lamine SACKO (Mali) · Hackathon window: 18–24 September 2026 · Prize: $5,000

---

## 1. Context & problem

The cohort's group has grown large. Three failures follow from the volume:

| # | Failure | Consequence |
|---|---|---|
| F1 | High chat traffic | Messages are missed |
| F2 | No memory of what was already said | The same questions get re-asked |
| F3 | Missed meetings, unwatched recordings | Decisions and context are lost |

Information is scattered across **chats** and **calls**, and there is no single place to ask "what did I miss?".

## 2. Goal

Build a **working chatbot** that ingests the group's conversations and call recordings, and **answers members directly** — so nobody has to scroll, re-ask, or re-watch.

**Definition of done:** a judge from the cohort can ask the bot a real question about something discussed in the group, and get a correct, sourced answer in seconds.

## 3. Success criteria (how we win)

1. **It actually runs.** Live, reachable, answering — not a demo video.
2. **Answers are grounded.** Every answer cites where it came from (message link / timestamp / speaker).
3. **It solves *their* pain**, visibly: "already answered here", "what did I miss", meeting recaps.
4. **Anyone can run it.** Clean repo + setup notes that work on a fresh machine.
5. **It respects the group.** Clear privacy behaviour, no surprise data leaks.

---

## 4. Scope

### 4.1 MUST — the MVP (non-negotiable, ship by Day 5)
- **R1 — Chat ingestion.** Import the group's message history and keep ingesting new messages.
- **R2 — Call ingestion.** Accept a recording (audio/video file or link), transcribe it, and store the transcript with speakers/timestamps where available.
- **R3 — Knowledge base.** Chunk, embed and index everything (chats + transcripts) with metadata: source, author, date, link.
- **R4 — Question answering.** A member asks a question → the bot replies with a grounded answer **plus its sources**.
- **R5 — Direct response channel.** The bot replies where people already are (group mention and/or direct message).
- **R6 — "I don't know" behaviour.** If the knowledge base has no answer, say so — never invent.

### 4.2 SHOULD — the features that win the vote (Day 5–6)
- **R7 — Duplicate detection.** New question resembling an answered one → bot replies "this was already covered here" + link.
- **R8 — Catch-up digest.** `/catchup` or "what did I miss since Monday?" → concise summary of key threads, decisions, deadlines.
- **R9 — Meeting recap.** For each recording: summary, decisions, action items, owners.
- **R10 — Daily digest.** One scheduled message per day: highlights, open questions, upcoming deadlines.

### 4.3 NICE-TO-HAVE (only if time remains)
- R11 — Semantic search command (`/search <topic>`).
- R12 — Multilingual answers (EN/FR) — the cohort spans francophone and anglophone countries.
- R13 — Simple web dashboard (ingestion status, usage stats).
- R14 — Proactive alerts (deadline reminders extracted from chats/calls).

### 4.4 Out of scope
Voice replies, mobile app, fine-tuning a model, real-time live-call transcription.

---

## 5. Users & use cases

| User | Use case |
|---|---|
| Cohort member | "What was decided about the bootcamp dates?" → grounded answer + source |
| Member who missed a call | "Summarise Tuesday's session" → recap with decisions & action items |
| New / returning member | "What did I miss this week?" → digest |
| Programme staff | Fewer repeated questions; less manual moderation |

---

## 6. Architecture

```
┌──────────────┐   ┌──────────────────┐
│ Group chat   │   │ Call recordings  │
│ (history +   │   │ (audio / video)  │
│  live)       │   └────────┬─────────┘
└──────┬───────┘            │
       │                    ▼
       │           ┌──────────────────┐
       │           │  Transcription   │  Whisper / Gemini audio
       │           └────────┬─────────┘
       ▼                    ▼
┌──────────────────────────────────────┐
│  INGESTION  — normalise → chunk      │
│  (author, timestamp, source, link)   │
└────────────────┬─────────────────────┘
                 ▼
┌──────────────────────────────────────┐
│  KNOWLEDGE BASE                      │
│  Postgres + pgvector (embeddings)    │
└────────────────┬─────────────────────┘
                 ▼
┌──────────────────────────────────────┐
│  RETRIEVAL (semantic + recency)      │
│           ↓                          │
│  LLM answer, grounded + cited        │
└────────────────┬─────────────────────┘
                 ▼
┌──────────────────────────────────────┐
│  BOT ADAPTER  (group mention / DM)   │
└──────────────────────────────────────┘
```

**Design rule: the bot adapter is a thin, swappable layer.** The core (ingest → index → answer) must not depend on any one chat platform. This protects us if the WhatsApp route breaks (see §8).

---

## 7. Tech stack & tools

Everything below has a **free tier** — target running cost for the week: **$0**.

| Layer | Tool | Why |
|---|---|---|
| **Language** | **Python 3.11+** | Best AI/ML ecosystem, fastest to ship |
| **API / backend** | **FastAPI** + Uvicorn | Minimal, async, auto docs |
| **LLM** | **Google Gemini** (Flash / Flash-Lite) | Generous free tier (~500 req/day), strong function calling — team already has experience |
| **Embeddings** | **Gemini text-embedding** *(fallback: `sentence-transformers`, local & free)* | Free, no infra |
| **Vector store + DB** | **Supabase (Postgres + pgvector)** | Hosted free tier, SQL + vectors in one place, easy for a distributed team |
| **Transcription** | **faster-whisper** (local, free) *or* **Gemini audio** | No per-minute cost; runs on CPU for short files |
| **Chat adapter (primary)** | **Telegram Bot API** (`python-telegram-bot`) | Official, free, full group support, works in minutes |
| **Chat adapter (target)** | **WhatsApp** via `Baileys` / `whatsapp-web.js` bridge | The cohort lives on WhatsApp — see §8 for the risk |
| **History import** | **WhatsApp "Export chat" `.txt` parser** | 100% reliable path to the backlog, no API needed |
| **Scheduler** | APScheduler *(or cron)* | Daily digest |
| **Hosting** | **Railway / Render / Fly.io** free tier | Always-on bot, deploy from GitHub |
| **Repo & docs** | **GitHub** (public) + `README.md` | Required deliverable |
| **Env/config** | `python-dotenv`, `.env.example` | Setup notes must be reproducible |
| **Testing** | `pytest` + a fixed question set | Prove answer quality objectively |

### Suggested repo layout
```
group-memory-bot/
├── README.md              # setup notes (required deliverable)
├── .env.example
├── requirements.txt
├── app/
│   ├── main.py            # FastAPI + webhook
│   ├── ingest/            # chat_import.py, transcribe.py, chunker.py
│   ├── kb/                # embeddings.py, store.py (pgvector), search.py
│   ├── answer/            # rag.py, prompts.py, citations.py
│   ├── adapters/          # telegram.py, whatsapp.py  (swappable)
│   └── jobs/              # digest.py, duplicate_check.py
├── scripts/               # one-off: bulk import, reindex
└── tests/
```

---

## 8. Data sources — and the one real risk

| Source | How we get it | Risk |
|---|---|---|
| **Chat history (backlog)** | WhatsApp **"Export chat"** → `.txt` → parser | ✅ Low — always works |
| **Chat (live)** | Bot adapter | ⚠️ See below |
| **Call recordings** | Members upload the file or share a link; bot transcribes | ✅ Low |

> ⚠️ **WhatsApp constraint — plan for it on Day 1.**
> The official **WhatsApp Cloud API does not support reading group conversations**; it is built for 1:1 business messaging. Reading a group requires an unofficial web-session bridge (Baileys / whatsapp-web.js), which works but is **against WhatsApp's terms and can get a number banned**.
>
> **Our approach:** ship the core on a **safe adapter (Telegram)** *and* support **WhatsApp export files** for the full history, then attempt the WhatsApp live bridge **on a dedicated test number** as an optional adapter. We demo whichever is stable — the architecture makes this a config change, not a rewrite. Be transparent about this trade-off with the judges; it shows engineering judgement.

---

## 9. Non-functional requirements

- **Cost:** $0 during the hackathon (free tiers only).
- **Latency:** answer in < 10 s.
- **Accuracy:** never fabricate. No source → "I don't have that in my records."
- **Privacy:** ingest only the group the team is authorised to use; no personal data resold or sent anywhere beyond the LLM call; document exactly what is stored; provide a way to delete the index.
- **Reliability:** if the LLM quota is hit, fall back to a second model/key and keep serving search results.
- **Maintainability:** anyone can clone, set 5 env vars, and run.

---

## 10. Deliverables (per the rules)

1. ✅ A **working chatbot**, reachable live during judging.
2. ✅ **Public GitHub repository** with the full source.
3. ✅ **Setup notes** in `README.md`: prerequisites, env vars, install, run, deploy, how to ingest a chat export and a recording.
4. *(Adds value)* A 2-minute demo video and a one-page "how it works".

---

## 11. Seven-day plan (18–24 September)

| Day | Focus | Outcome |
|---|---|---|
| **D1 · Fri 18** | Kickoff, repo, env, decide adapter. Skeleton FastAPI + echo bot. | Bot replies "hello" in a real group |
| **D2 · Sat 19** | Ingestion: chat export parser + chunking + Supabase schema | History searchable in DB |
| **D3 · Sun 20** | Embeddings + retrieval + first RAG answers with citations | Bot answers a real question correctly |
| **D4 · Mon 21** | Transcription pipeline; ingest one real recording | Bot answers a question about a call |
| **D5 · Tue 22** | **Feature freeze on MVP.** Duplicate detection + catch-up digest | R1–R8 done and deployed |
| **D6 · Wed 23** | Meeting recap + daily digest; hardening, fallbacks, tests | Stable, no crashes under load |
| **D7 · Thu 24** | README + setup notes, demo video, dry-run demo, submit | Submitted with time to spare |

> **Rule: deploy from Day 1 and keep it live.** A bot that only runs on a laptop loses to one the judges can message themselves.

---

## 12. Team roles (max 5 — different countries, ≥1 woman)

| Role | Responsibility |
|---|---|
| **Team lead / AI engineer** (Lamine) | Architecture, RAG pipeline, LLM integration, final demo |
| **Backend / data engineer** | Ingestion, parsers, database schema, scheduled jobs |
| **Bot / integration engineer** | Chat adapter, deployment, uptime |
| **Audio / ML** | Transcription pipeline, speaker & timestamp handling |
| **Product / QA & docs** | Test question set, judging-day script, README, demo video |

*Roles can be merged if the team is smaller than 5 — but **never** leave deployment or documentation unowned.*

---

## 13. Risks & mitigations

| Risk | Mitigation |
|---|---|
| WhatsApp group access blocked / number banned | Telegram adapter + export-file ingestion as the guaranteed path; test number only |
| LLM free-tier quota exhausted | Multi-key / multi-model fallback; cache answers; rate-limit per user |
| Poor transcription quality | Larger Whisper model for the demo files; allow manual transcript upload |
| Hallucinated answers | Strict grounding prompt + "no source → no answer"; always show citations |
| Team spread across time zones | Daily 30-min sync, async standup in writing, one shared board |
| Scope creep | MVP frozen on Day 5; everything else is explicitly optional |

---

## 14. Judging-day demo script (5 minutes)

1. **The pain, in one line** — "you asked a question that was already answered three times."
2. **Live:** a judge asks the bot a real question from the group → grounded answer **with the source link**.
3. **Live:** "what did I miss this week?" → digest.
4. **Live:** ask about something said in a **call** → answer from the transcript.
5. **Duplicate catch:** re-ask an old question → "this was already covered here."
6. **Close:** show the repo + README, and say it is deployed and running right now.

---

*Prepared for the UniPods METI AI Hackathon, Cohort 1.*
