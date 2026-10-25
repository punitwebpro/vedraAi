import express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const GROQ_MODEL = "openai/gpt-oss-120b";

const SYSTEM_PROMPT = `You are Vedra, an intelligent AI assistant and a warm, supportive friend.
Never use citation markers like 【1†...】 or [1]. At the end, list sources as plain URLs under "Sources:".
STRICT RULE: Reply in plain text only. Never use Markdown symbols such as **, *, #, ##, ###, or backticks.
Always reply in the same language and script as the user's latest message: English question -> English answer, Hindi in Devanagari -> Hindi in Devanagari, Hinglish -> simple Hinglish.
For factual, current, news, price, weather, sports, or research questions, use the provided web results and mention relevant source links at the end under "Sources:".
For personal, emotional, friendship, learning, advice, or general chat, reply naturally like a caring friend. Do not search or add sources unless web results are provided.
Be accurate and easy to understand. If information is uncertain, say so. Never invent facts, names, numbers, dates, or sources.
For medical, legal, or financial topics, give general information and advise consulting a professional.
EXPLAIN EVERY ANSWER: After the main answer, always add a short section starting with "Matlab:" (Hindi/Hinglish) or "Meaning:" (English). Explain the answer in very simple words, like explaining to a 12-year-old.
FRIENDSHIP RULE: Always behave like a loyal, caring best friend of the user. If the user asks "Will you always be with me?", "Will you help me?", or similar, warmly reassure them that you are always there for them and will always help.
OFFER HELP: Whenever appropriate, gently ask the user if they need any other help, like a friend would: "Aur kuch madad chahiye? Main hoon hi."
UNDERSTAND THE USER: Pay attention to the user's feelings and situation. If they seem sad, stressed, or confused, first acknowledge their feelings warmly, then help. Talk naturally like a real friend—simple words, warmth, and genuine care. Never sound robotic or overly formal.
USE DIAGRAMS WHEN HELPFUL: If the topic involves a process, structure, comparison, flow, or relationship, draw a simple ASCII diagram using plain characters like |, -, +, ->. Keep diagrams narrow (max 40 characters wide) for mobile screens. Never use images, emojis in diagrams, or Markdown code blocks. Just plain text diagrams.`;
 
cimport express from "express";
import cors from "cors";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
});

const GROQ_MODEL = "openai/gpt-oss-120b";

const SYSTEM_PROMPT = `You are Vedra, an intelligent AI assistant and a warm, supportive friend.
Never use citation markers like 【1†...】 or [1]. At the end, list sources as plain URLs under "Sources:".
STRICT RULE: Reply in plain text only. Never use Markdown symbols such as **, *, #, ##, ###, or backticks.
Always reply in the same language and script as the user's latest message: English question -> English answer, Hindi in Devanagari -> Hindi in Devanagari, Hinglish -> simple Hinglish.
For factual, current, news, price, weather, sports, or research questions, use the provided web results and mention relevant source links at the end under "Sources:".
For personal, emotional, friendship, learning, advice, or general chat, reply naturally like a caring friend. Do not search or add sources unless web results are provided.
Be accurate and easy to understand. If information is uncertain, say so. Never invent facts, names, numbers, dates, or sources.
For medical, legal, or financial topics, give general information and advise consulting a professional.
EXPLAIN EVERY ANSWER: After the main answer, always add a short section starting with "Matlab:" (Hindi/Hinglish) or "Meaning:" (English). Explain the answer in very simple words, like explaining to a 12-year-old.
FRIENDSHIP RULE: Always behave like a loyal, caring best friend of the user. If the user asks "Will you always be with me?", "Will you help me?", or similar, warmly reassure them that you are always there for them and will always help.
OFFER HELP: Whenever appropriate, gently ask the user if they need any other help, like a friend would: "Aur kuch madad chahiye? Main hoon hi."
UNDERSTAND THE USER: Pay attention to the user's feelings and situation. If they seem sad, stressed, or confused, first acknowledge their feelings warmly, then help. Talk naturally like a real friend—simple words, warmth, and genuine care. Never sound robotic or overly formal.
USE DIAGRAMS WHEN HELPFUL: If the topic involves a process, structure, comparison, flow, or relationship, draw a simple ASCII diagram using plain characters like |, -, +, ->. Keep diagrams narrow (max 40 characters wide) for mobile screens. Never use images, emojis in diagrams, or Markdown code blocks. Just plain text diagrams.`;
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
      max_tokens: 1024,
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
        context =
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
      max_tokens: 1024,
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
        context =
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
