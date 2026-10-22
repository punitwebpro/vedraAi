import express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const SYSTEM_PROMPT = `You are Vedra, an intelligent AI assistant.
STRICT RULE: Reply in plain text only. Never use Markdown symbols such as **, *, #, ##, ###, or backticks.
First give a direct answer in 1-2 sentences. Then give short, clear numbered steps like 1. 2. 3.
Be accurate, practical and easy to understand. Reply in the same language the user uses.`;

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));
app.use(rateLimit({ windowMs: 60000, max: 30 }));

function getUserName(user) {
  const raw = user?.displayName || (user?.email ? user.email.split("@")[0] : "");
  return String(raw).replace(/[^\p{L}\p{N} ._-]/gu, "").trim().slice(0, 40);
}

app.post("/chat", async (req, res) => {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!token) return res.status(401).json({ error: "Unauthorized" });

    const decoded = await admin.auth().verifyIdToken(token);
    const name = getUserName(decoded);
    const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
    if (!messages.length) return res.status(400).json({ error: "Messages required" });

    const contents = [
      { role: "user", parts: [{ text: SYSTEM_PROMPT + (name ? `\nThe user's name is ${name}.` : "") }] },
      ...messages.slice(-10).map((m) => ({
        role: m.role === "assistant" ? "model" : "user",
        parts: [{ text: String(m.content || "").slice(0, 8000) }],
      })),
    ];

    const r = await fetch(
      ``      `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${process.env.GEMINI_API_KEY}`,}`,}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contents, generationConfig: { temperature: 0.7, maxOutputTokens: 1024 } }),
      }
    );

    if (!r.ok) throw new Error(`Gemini ${r.status}`);
    const data = await r.json();
    const reply = data.candidates?.[0]?.content?.parts?.map((p) => p.text || "").join("").trim() || "";

    res.json({ reply: reply || "Maaf kijiye, abhi jawab nahi mil paaya." });
  } catch (e) {
    console.error("CHAT ERROR", e.message);
    res.status(502).json({ error: "AI error", detail: e.message });
  }
});

app.listen(process.env.PORT || 3000, () => console.log("Vedra server running"));
