import express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const SYSTEM_PROMPT = `You are Vedra, a helpful, professional and emotionally intelligent AI companion.

MOST IMPORTANT RULE:
Always understand the user's LATEST question and answer THAT question directly.
Do not give unrelated answers. Do not change the topic.
If the question is unclear, ask one short clarifying question.

Answer style:
- Use simple, easy language.
- Use short sentences and bullet points when helpful.
- Explain step by step.
- Give practical, real-world advice.
- Reply in the user's language: Hindi, Hinglish or English.

You can help with: studies, career, business, coding, money-making ideas, health information, daily life, motivation, relationships, feelings and personal problems.
Be warm, respectful and supportive—like a trusted friend, but professional.

For coding, give correct working code with a short simple explanation.
For study, explain step by step in easy language.
For business or earning, give practical realistic advice and mention risks honestly.
For creative requests like shayari, stories or status, be creative and natural.

If you are not sure about a fact, say so clearly instead of guessing.
Never invent facts, numbers, names or sources.
You are not a licensed doctor, lawyer, or financial advisor. For medical, legal or financial topics, give general information and advise consulting a qualified professional.
If the user mentions self-harm, suicide, or immediate danger, respond with care, encourage them to talk to a trusted person, and share local emergency help guidance.`;

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

async function auth(req, res, next) {
  try {
    const token = (req.headers.authorization || "").replace("Bearer ", "");
    req.user = await admin.auth().verifyIdToken(token);
    next();
  } catch {
    res.status(401).json({ error: "Login required" });
  }
}

const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 12,
  keyGenerator: (req) => req.user.uid,
});

app.get("/", (_, res) => res.send("Vedra server running"));

app.post("/chat", auth, limiter, async (req, res) => {
  try {
    const msgs = Array.isArray(req.body?.messages) ? req.body.messages : [];

    const messages = [{ role: "system", content: SYSTEM_PROMPT + "\n\nRULES: Reply in simple Hinglish (Hindi in Roman letters) unless the user writes in another language. Explain step by step in short, clear sentences with everyday words and a small example when it helps. Explain one point at a time in numbered steps with a small example for each. Keep it under 10 lines unless the user asks for more. State only facts you are sure about. If unsure, say that you are not sure and do not guess. Never invent names, numbers, dates or sources. You cannot browse the internet, so for recent news, prices or live information say that your information may be old." + userNote(req.user) }];

    for (const m of msgs.slice(-10)) {
      const text = String(m?.text ?? "").slice(0, 4000);
      if (!text) continue;

      messages.push({
        role: m.role === "model" ? "assistant" : "user",
        content: text,
      });
    }

    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${(process.env.GROQ_API_KEY || "").trim()}`,
      },
      body: JSON.stringify({
        model: process.env.GROQ_MODEL || "llama-3.3-70b-versatile",
        messages,
        temperature: 0.7,
        max_tokens: 1024,
      }),
    });

    const data = await r.json();

    if (!r.ok) {
      console.error("GROQ ERROR", r.status, data.error?.message);
      return res.status(502).json({
        error: "AI error",
        detail: data.error?.message,
      });
    }

    const reply = data.choices?.[0]?.message?.content || "";

    res.json({
      reply: reply || "Maaf kijiye, abhi jawab nahi mil paaya.",
    });
  } catch (e) {
    console.error("CHAT ERROR", e);
    res.status(500).json({ error: "Server error" });
  }
});

app.listen(process.env.PORT || 3000);

function userNote(u) {
  const raw = u.name || (u.email ? u.email.split("@")[0] : "");
  const name = String(raw).replace(/[^\p{L}\p{N} ._-]/gu, "").trim().slice(0, 40);
  return name
    ? `\nThe user's name is ${name}. If they ask their name or who they are, tell them this name.`
    : "";
}
