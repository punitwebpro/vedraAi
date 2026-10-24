import express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const MODEL = "gemini-flash-latest";

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

function callGemini(body) {
  return fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": process.env.GEMINI_API_KEY,
      },
      body: JSON.stringify(body),
    }
  );
}

app.post("/chat", async (req, res) => {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!token) return res.status(401).json({ error: "Unauthorized" });

    const decoded = await admin.auth().verifyIdToken(token);
    const name = getUserName(decoded);

    const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
    const contents = messages
      .slice(-12)
      .map((m) => ({
        role: m.role === "model" || m.role === "assistant" ? "model" : "user",
        parts: [{ text: String(m.text ?? m.content ?? "").slice(0, 8000) }],
      }))
      .filter((c) => c.parts[0].text.trim());
    while (contents.length && contents[0].role === "model") contents.shift();
    if (!contents.length) return res.status(400).json({ error: "Messages required" });

    const note = name
      ? `\nThe user's name is ${name}. If they ask their name or who they are, tell them this name.`
      : "";
    const base = {
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT + note }] },
      contents,
      generationConfig: { temperature: 0.5, maxOutputTokens: 1024 },
    };

    let r = await callGemini({ ...base, tools: [{ google_search: {} }] });
    if (!r.ok) {
      console.error("Gemini with search failed", r.status);
      r = await callGemini(base);
    }
    const data = await r.json();
    if (!r.ok) {
      console.error("GEMINI ERROR", r.status, JSON.stringify(data.error || data).slice(0, 500));
      return res.status(502).json({ error: "AI error", detail: `Gemini ${r.status}` });
    }

    const reply = (data.candidates?.[0]?.content?.parts || [])
      .map((p) => p.text || "")
      .join("")
      .trim();
    res.json({ reply: reply || "Maaf kijiye, abhi jawab nahi mil paaya." });
  } catch (e) {
    console.error("CHAT ERROR", e.message);
    res.status(502).json({ error: "AI error", detail: e.message });
  }
});

app.listen(process.env.PORT || 3000, () => console.log("Vedra server running"));
