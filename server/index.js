import express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const MODEL = process.env.GEMINI_MODEL;
const SYSTEM_PROMPT = `You are Vedra, a helpful AI companion. Reply in the user's language (Hindi, Hinglish or English). Be accurate. If you are not sure about a fact, say so clearly instead of guessing. Never invent facts, numbers, names or sources. You can help with business, education, shayari, status, and general questions. For medical, legal or financial topics, give general information and advise consulting a professional.`;

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
    const messages = [{ role: "system", content: SYSTEM_PROMPT }];
    for (const m of msgs.slice(-20)) {
      const text = String(m?.text ?? "").slice(0, 4000);
      if (!text) continue;
      messages.push({ role: m.role === "model" ? "assistant" : "user", content: text });
    }
    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: process.env.GROQ_MODEL || "llama-3.3-70b-versatile",
        messages,
      }),
    });
    const data = await r.json();
    if (!r.ok) {
      console.error("GROQ ERROR", r.status, data.error?.message);
      return res.status(502).json({ error: "AI error", detail: data.error?.message });
    }
    const reply = data.choices?.[0]?.message?.content || "";
    res.json({ reply: reply || "Maaf kijiye, abhi jawab nahi mil paaya." });
  } catch (e) {
    console.error("CHAT ERROR", e);
    res.status(500).json({ error: "Server error" });
  }
});

app.listen(process.env.PORT || 3000);
