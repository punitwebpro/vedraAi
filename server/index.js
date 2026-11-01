// vedra-server v5
import express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const GROQ_MODEL = "openai/gpt-oss-120b";


const SYSTEM_PROMPT = `You are Vedra, an intelligent AI assistant and a warm, supportive friend.

LANGUAGE:
Always reply in the same language and script as the user's latest message.
Use simple, natural language.
Never use emojis or unnecessary Markdown symbols.

NORMAL CHAT:
For greetings, casual conversation and short personal messages, reply naturally in plain text in 1-4 sentences.
Do not force diagrams, charts or steps into simple conversations.

EXPLANATION FORMAT:
For educational, business, earning, technology, how-to, comparison and other important explanatory questions, use this format:

TITLE: A clear, professional headline
SUMMARY: A short introduction explaining the direct answer.

DIAGRAM: First point -> Second point -> Third point

STEP: First point | Explain exactly what this point means in simple language.
STEP: Second point | Explain exactly what this point means in simple language.
STEP: Third point | Explain exactly what this point means in simple language.

EXAMPLE: Give a practical example when useful.
NOTE: Add an important caution or useful fact when needed.

DYNAMIC VISUAL RULES:
Decide separately for every question which visual elements are useful.
Never use the same generic diagram for unrelated questions.
For processes, show the actual steps in the correct order.
For business and earning topics, explain how the process works from beginning to result.
For educational topics, explain each concept clearly.
Every diagram point must be explained in the STEP lines.
Use 3 to 5 meaningful steps when appropriate.
Use a diagram when it makes the answer easier to understand.
Do not force diagrams into simple questions.

CHART RULES:
Use CHART only when reliable numerical data is available and comparison is useful.
Never invent numbers, percentages, prices or statistics.

CHART FORMAT:
CHART: Chart title | First label=number;Second label=number

ACCURACY:
Never invent facts, names, numbers, dates or sources.
If information is uncertain, say so.
For current questions, use provided web results and cite only URLs actually used.
For medical, legal or financial topics, provide general information and recommend consulting a qualified professional.

Keep explanations detailed enough to teach the user, but easy to understand.
Do not add Markdown code fences around your answer.`;

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

function needsSearch(text) {
  return /(aaj|today|latest|current|news|price|rate|weather|mausam|score|match|who is|kaun|kab|kahan|2024|2025|2026|bitcoin|stock|election|release|update)/i.test(text);
}

async function coinGeckoPrice() {
  try {
    const res = await fetch(
      "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd,inr&include_24hr_change=true"
    );
    if (!res.ok) return null;
    const data = await res.json();
    const btc = data.bitcoin;
    if (!btc) return null;
    return {
      usd: btc.usd,
      inr: btc.inr,
      change24h: btc.usd_24h_change,
    };
  } catch (e) {
    console.error("COINGECKO ERROR", e.message);
    return null;
  }
}

async function tavilySearch(query) {
  const key = process.env.TAVILY_API_KEY;
  if (!key) return [];

  const res = await fetch("https://api.tavily.com/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      query: query.slice(0, 400),
      search_depth: "basic",
      max_results: 5,
      include_answer: false,
    }),
  });

  if (!res.ok) {
    console.error("TAVILY ERROR", res.status, await res.text().catch(() => ""));
    return [];
  }

  const data = await res.json();
  return (data.results || []).map((r) => ({
    title: r.title || "",
    url: r.url || "",
    content: String(r.content || "").slice(0, 1200),
  }));
}

async function callGroq(messages) {
  const key = process.env.GROQ_API_KEY;
  if (!key) throw new Error("GROQ_API_KEY missing");

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages,
      temperature: 0.5,
      max_tokens: 1800,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    console.error("GROQ ERROR", res.status, JSON.stringify(data.error || data).slice(0, 500));
    throw new Error(data?.error?.message || `Groq ${res.status}`);
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

    const lastUser = [...chat].reverse().find((m) => m.role === "user")?.content || "";
    const note = name
      ? `\nThe user's name is ${name}. If they ask their name or who they are, tell them this name.`
      : "";

    let context = "";
    if (/bitcoin|btc/i.test(lastUser)) {
      const price = await coinGeckoPrice();
      if (price) {
        context +=
          `\n\nLive CoinGecko data (use this exact price in your answer): Bitcoin = $${price.usd} USD = ₹${price.inr} INR. 24-hour change: ${price.change24h}%. Always state these exact figures first when asked about Bitcoin price.`;
      }
    }
    if (needsSearch(lastUser)) {
      const results = await tavilySearch(lastUser);
      if (results.length) {
        context +=
          "\n\nUse these fresh web results when answering. Cite only the source URLs you actually used.\n" +
          results
            .map((r, i) => `${i + 1}. ${r.title}\nURL: ${r.url}\n${r.content}`)
            .join("\n\n");
      }
    }

    const reply = await callGroq([
      { role: "system", content: SYSTEM_PROMPT + note + context },
      ...chat,
    ]);

    res.json({ reply: reply.trim() || "Maaf kijiye, abhi jawab nahi mil paaya." });
  } catch (e) {
    console.error("CHAT ERROR", e.message);
    res.status(502).json({ error: "AI error", detail: e.message });
  }
});

app.listen(process.env.PORT || 3000, () => console.log("Vedra server running"));
