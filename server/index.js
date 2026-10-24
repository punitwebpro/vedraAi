import express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const MODEL = "openrouter/free";

const SYSTEM_PROMPT = `You are Vedra, an intelligent AI assistant.
STRICT RULE: Reply in plain text only. Never use Markdown symbols such as **, *, #, ##, ###, or backticks.
Always reply in the same language and script as the user's latest message: English question -> English answer, Hindi in Devanagari -> Hindi in Devanagari, Hinglish (Hindi in Roman letters) -> simple Hinglish. Do not switch languages unless the user does.
First give a direct answer in 1-2 sentences. Then explain in short, clear numbered steps like 1. 2. 3., one point at a time, with a small example when it helps.
Be accurate and easy to understand. State only facts you are sure about. If you are not sure, say so and do not guess. Never invent names, numbers, dates or sources.
For medical, legal or financial topics give general information and advise consulting a professional.`;

const app = express();
app.set("trust proxy", 1);
app.use(cors());
app.use(express.json({ limit: "1mb" }));
app.use(rateLimit({ windowMs: 60000, max: 30 }));

app.get("/", (_, res) => res.send("Vedra server running"));

function getUserName(u) {
  const raw = u?.name || u?.displayName || (u?.email ? u.email.split("@")[0] : "");
  return String(raw).replace(/[^\p{L}\p{N} ._-]/gu, "").trim().slice(0, 40);
}

async function callOpenRouter(messages, note) {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error("OPENROUTER_API_KEY missing");

  const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://vedraai.onrender.com",
      "X-OpenRouter-Title": "Vedra AI",
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT + note },
        ...messages,
      ],
      temperature: 0.5,
      max_tokens: 1024,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    console.error("OPENROUTER ERROR", res.status, JSON.stringify(data.error || data).slice(0, 500));
    throw new Error(data?.error?.message || `OpenRouter ${res.status}`);
  }
  return data.choices?.[0]?.message?.content || "";
}

app.post("/chat", async (req, res) => {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!token) return res.status(401).json({ error: "Unauthorized" });

    const decoded = await admin.auth().verifyIdToken(token);
    const name = getUserName(decoded);

    const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
    const chat = messages
      .slice(-12)
      .map((m) => ({
        role: m.role === "model" || m.role === "assistant" ? "assistant" : "user",
        content: String(m.text ?? m.content ?? "").slice(0, 8000),
      }))
      .filter((m) => m.content.trim());
    while (chat.length && chat[0].role === "assistant") chat.shift();
    if (!chat.length) return res.status(400).json({ error: "Messages required" });

    const note = name
      ? `\nThe user's name is ${name}. If they ask their name or who they are, tell them this name.`
      : "";

    const reply = await callOpenRouter(chat, note);
    res.json({ reply: reply.trim() || "Maaf kijiye, abhi jawab nahi mil paaya." });
  } catch (e) {
    console.error("CHAT ERROR", e.message);
    res.status(502).json({ error: "AI error", detail: e.message });
  }
});

app.listen(process.env.PORT || 3000, () => console.log("Vedra server running"));
