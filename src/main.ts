import { initializeApp } from "firebase/app";


/* ------ IMPORTING FIREBASE AUTHENTICATION TOOLS ------ */

import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
} from "firebase/auth";


/* ------ IMPORTING FIREBASE DATABASE TOOLS ------ */

import {
  getFirestore,
  collection,
  addDoc,
  onSnapshot,
  query,
  where,
  orderBy,
  serverTimestamp,
  doc,
  updateDoc,
  deleteDoc,
  limit,
  getDocs,
  Timestamp,
} from "firebase/firestore";


/* ------ IMPORTING FIREBASE STORAGE TOOLS ------ */

import { 
    getStorage,
    ref,
    uploadBytes,
} from "firebase/storage";


/* ------ IMPORTING FIREBASE AI TOOLS ------ */

import { 
    getAI, 
    getGenerativeModel, 
    GoogleAIBackend, 
} from "firebase/ai";


/* ------ IMPORTING FIREBASE CONFIGURATION ------ */

import { firebaseConfig } from "./firebase.js";


/* ------ IMPORTING STYLES ------ */

import "../styles.css";


/* ------ IMPORTING PDF.JS LIBRARY ------ */

import * as pdfjsLib from "pdfjs-dist/legacy/build/pdf.mjs";
import pdfjsWorker from "pdfjs-dist/legacy/build/pdf.worker.min.mjs?url";

(pdfjsLib as any).GlobalWorkerOptions.workerSrc = pdfjsWorker;


/* ------ FIREBASE INITIALIZATION ------ */

const app = initializeApp(firebaseConfig);

const auth = getAuth(app);

const db = getFirestore(app);

const storage = getStorage(app);

const ai = getAI(app, { backend: new GoogleAIBackend() });

const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });


/* ------ DEFINING HELPER FUNCTIONS ------ */

function mustGet<T extends HTMLElement>(id: string): T {
  const el = document.getElementById(id);
  if (!el) throw new Error(`Missing element with id="${id}"`);
  return el as T;
}

function setMsg(el: HTMLElement, text: string, kind = "") {
  el.textContent = text || "";
  el.classList.remove("error", "ok");
  if (kind) el.classList.add(kind);
}

function requireUser() {
  const u = auth.currentUser;
  if (!u) throw new Error("Not signed in");
  return u;
}

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => {
    switch (c) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      case "'":
        return "&#39;";
      default:
        return c;
    }
  });
}

function yieldToBrowser() {
  return new Promise<void>((r) => setTimeout(() => r(), 0));
}


/* ------ DEFINING UI REFERENCE ------ */

const authCard = mustGet<HTMLDivElement>("authCard");
const appCard = mustGet<HTMLDivElement>("appCard");

const authForm = mustGet<HTMLFormElement>("authForm");
const emailEl = mustGet<HTMLInputElement>("email");
const passwordEl = mustGet<HTMLInputElement>("password");
const signInBtn = mustGet<HTMLButtonElement>("signInBtn");
const signUpBtn = mustGet<HTMLButtonElement>("signUpBtn");
const authMsg = mustGet<HTMLDivElement>("authMsg");

const userEmail = mustGet<HTMLSpanElement>("userEmail");
const signOutBtn = mustGet<HTMLButtonElement>("signOutBtn");

const pdfFile = mustGet<HTMLInputElement>("pdfFile");
const uploadPdfBtn = mustGet<HTMLButtonElement>("uploadPdfBtn");
const docsList = mustGet<HTMLUListElement>("docsList");
const docsLoader = mustGet<HTMLDivElement>("docsLoader");

const chatLog = mustGet<HTMLDivElement>("chatLog");
const chatForm = mustGet<HTMLFormElement>("chatForm");
const chatText = mustGet<HTMLInputElement>("chatText");


const appMsg = mustGet<HTMLDivElement>("appMsg");


/* ------ SHOWING ERROR MESSAGES ------ */

window.addEventListener("error", (e) => {
  console.error("Window error:", (e as any).error || e.message);
  setMsg(appMsg, `JS Error: ${e.message}`, "error");
});

window.addEventListener("unhandledrejection", (e: PromiseRejectionEvent) => {
  console.error("Unhandled rejection:", e.reason);
  const msg = e.reason?.message || String(e.reason);
  const name = e.reason?.name ? `${e.reason.name}: ` : "";
  setMsg(appMsg, `Promise Error: ${name}${msg}`, "error");
});


/* ------ COLLECTIONS IN FIRESTORE DATABASE ------ */

function docsRef(uid: string) {
  return collection(db, "users", uid, "docs");
}
function chunksRef(uid: string, docId: string) {
  return collection(db, "users", uid, "docs", docId, "chunks");
}
function messagesRef(uid: string, docId: string) {
  return collection(db, "users", uid, "docs", docId, "messages");
}
function remindersRef(uid: string) {
  return collection(db, "users", uid, "reminders");
}


/* ------ DEFINING STATE VARIABLES ------ */

let unsubscribeDocs: null | (() => void) = null;
let unsubscribeChunks: null | (() => void) = null;
let unsubscribeMessages: null | (() => void) = null;

let currentDocId: string | null = null;
let currentChunks: Array<{ id: string; text: string; page: number }> = [];


/* ------ DEFINING AUTHENTICATION HANDLERS ------ */

authForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  setMsg(authMsg, "");
  setMsg(appMsg, "");

  const email = emailEl.value.trim();
  const password = passwordEl.value;

  signInBtn.disabled = true;
  signUpBtn.disabled = true;
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (err: any) {
    setMsg(authMsg, err?.message || "Sign in failed", "error");
  } finally {
    signInBtn.disabled = false;
    signUpBtn.disabled = false;
  }
});

signUpBtn.addEventListener("click", async (e) => {
  e.preventDefault();
  setMsg(authMsg, "");
  setMsg(appMsg, "");

  const email = emailEl.value.trim();
  const password = passwordEl.value;

  if (!email || !password) return setMsg(authMsg, "Enter email and password.", "error");
  if (password.length < 8) return setMsg(authMsg, "Password must be 8+ chars.", "error");

  signInBtn.disabled = true;
  signUpBtn.disabled = true;
  try {
    await createUserWithEmailAndPassword(auth, email, password);
    setMsg(authMsg, "Account created. Signed in.", "ok");
  } catch (err: any) {
    setMsg(authMsg, err?.message || "Sign up failed", "error");
  } finally {
    signInBtn.disabled = false;
    signUpBtn.disabled = false;
  }
});

signOutBtn.addEventListener("click", async () => {
  await signOut(auth);
});


/* ------ DEFINING DOCUMENT HANDLERS ------ */

function startDocsListener(uid: string) {
  if (unsubscribeDocs) unsubscribeDocs();
  docsList.innerHTML = "";
  docsLoader.classList.remove("hidden");

  unsubscribeDocs = onSnapshot(
    query(docsRef(uid), orderBy("createdAt", "desc")),
    (snap) => {
      docsLoader.classList.add("hidden");
      docsList.innerHTML = "";

      snap.forEach((d) => {
        const data = d.data() as any;
        const li = document.createElement("li");
        li.className = "item";
        li.innerHTML = `
          <div class="title">${escapeHtml(data.title || "Untitled")}</div>
          <div class="muted small">${escapeHtml(data.summary || "No summary yet.")}</div>
        `;
        li.addEventListener("click", () => selectDoc(uid, d.id, data.title || d.id));
        docsList.appendChild(li);
      });
    },
    (err: any) => {
      docsLoader.classList.add("hidden");
      setMsg(appMsg, err?.message || "Failed to load docs", "error");
    },
  );
}


function selectDoc(uid: string, docId: string, title: string) {
  currentDocId = docId;
  setMsg(appMsg, `Selected: ${title}`, "ok");


  if (unsubscribeChunks) unsubscribeChunks();
  unsubscribeChunks = onSnapshot(
    query(chunksRef(uid, docId), orderBy("createdAt", "asc"), limit(400)),
    (snap) => {
      currentChunks = snap.docs.map((d) => {
        const data = d.data() as any;
        return { id: d.id, text: data.text || "", page: data.page || 0 };
      });
    },
  );


  if (unsubscribeMessages) unsubscribeMessages();
  unsubscribeMessages = onSnapshot(
    query(messagesRef(uid, docId), orderBy("createdAt", "asc"), limit(60)),
    (snap) => {
      chatLog.innerHTML = "";
      snap.forEach((m) => {
        const data = m.data() as any;
        appendChatMsg(data.role || "assistant", data.text || "");
      });
      chatLog.scrollTop = chatLog.scrollHeight;
    },
  );
}


/* ------ DEFINING PDF UPLOADING ------ */

uploadPdfBtn.addEventListener("click", async () => {
  setMsg(appMsg, "");
  const u = requireUser();
  const file = pdfFile.files?.[0];

  if (!file) return setMsg(appMsg, "Pick a PDF first.", "error");
  const MAX_INLINE_BYTES = 12 * 1024 * 1024; 
  if (file.size > MAX_INLINE_BYTES) {
    setMsg(
      appMsg,
      `PDF is ${(file.size / (1024 * 1024)).toFixed(1)}MB. This may exceed inline limits after base64. Try a smaller PDF for now.`,
      "error",
    );
    return;
  }

  uploadPdfBtn.disabled = true;
  docsLoader.classList.remove("hidden");

  async function fileToPdfPart(f: File) {
    const dataUrl = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onerror = () => reject(new Error("Failed to read file"));
      reader.onload = () => resolve(String(reader.result || ""));
      reader.readAsDataURL(f);
    });

    const base64 = dataUrl.split(",")[1] || "";
    return {
      inlineData: {
        data: base64,
        mimeType: f.type || "application/pdf",
      },
    };
  }

  function chunkTextSafe(full: string, maxLen: number, overlap: number): string[] {
    const out: string[] = [];
    const step = Math.max(1, maxLen - overlap);
    for (let start = 0; start < full.length; start += step) {
      const end = Math.min(full.length, start + maxLen);
      out.push(full.slice(start, end));
      if (end === full.length) break;
    }
    return out;
  }

  try {
    setMsg(appMsg, "Step 1/5: preparing…");
    const storagePath = `users/${u.uid}/pdfs/${Date.now()}-${file.name}`;

    setMsg(appMsg, "Step 2/5: uploading to Storage…");
    await uploadBytes(ref(storage, storagePath), file);

    setMsg(appMsg, "Step 3/5: creating Firestore doc…");
    const docMetaRef = await addDoc(docsRef(u.uid), {
      title: file.name,
      storagePath,
      createdAt: serverTimestamp(),
      summary: "",
      extractStatus: "processing",
      extractMethod: "gemini-inline",
    });

    setMsg(appMsg, "Step 4/5: Gemini extracting text from PDF…");
    const pdfPart = await fileToPdfPart(file); // file inputted here

    const prompt =
      `You will receive a PDF.\n` +
      `Return EXACTLY this format:\n` +
      `<SUMMARY>2-3 sentences about what the document is about.</SUMMARY>\n` +
      `<TEXT>All readable and unformatted text in reading order. If the PDF is scanned, do your best to transcribe. If no text is readable, leave empty.</TEXT>\n`;

    const result = await model.generateContent([prompt, pdfPart]);
    const raw = result.response.text() || "";

    const summary =
      raw.match(/<SUMMARY>([\s\S]*?)<\/SUMMARY>/i)?.[1]?.trim() || "";
    const extracted =
      raw.match(/<TEXT>([\s\S]*?)<\/TEXT>/i)?.[1]?.trim() || "";

    // Step 5/5: chunk + save
    setMsg(appMsg, "Step 5/5: saving chunks…");
    const chunkColl = chunksRef(u.uid, docMetaRef.id);

    const chunks =
      extracted.length > 0
        ? chunkTextSafe(extracted, 1200, 200)
        : ["(No readable text extracted. This PDF might be scanned/image-only.)"];

    let totalChunks = 0;
    for (let i = 0; i < chunks.length; i++) {
      await addDoc(chunkColl, {
        text: chunks[i],
        page: 0, // unknown when using Gemini extraction
        createdAt: serverTimestamp(),
        idx: i,
      });
      totalChunks++;
      await new Promise((r) => setTimeout(r, 0));
    }

    await updateDoc(doc(db, "users", u.uid, "docs", docMetaRef.id), {
      summary: summary || "(No summary returned.)",
      extractStatus: "done",
      totalChunks,
    });

    setMsg(appMsg, `Uploaded + Indexed (${totalChunks} chunks)`, "ok");
  } catch (err: any) {
    console.error(err);
    setMsg(appMsg, err?.message || String(err), "error");
  } finally {
    docsLoader.classList.add("hidden");
    uploadPdfBtn.disabled = false;
  }
});


/* ------ DEFINING CHAT SECTION ------ */

chatForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  setMsg(appMsg, "");

  const u = requireUser();
  const qText = chatText.value.trim();
  if (!qText) return;

  if (!currentDocId) return setMsg(appMsg, "Select a document first.", "error");

  chatText.value = "";

  await addDoc(messagesRef(u.uid, currentDocId), {
    role: "user",
    text: qText,
    createdAt: serverTimestamp(),
  });

  try {
    const top = pickTopChunks(qText, currentChunks, 6);
    const context = top
      .map((c) => `Page ${c.page}: ${c.text}`)
      .join("\n---\n")
      .slice(0, 20000);

    // pull recent messages for “recall”
    const histSnap = await getDocs(
      query(messagesRef(u.uid, currentDocId), orderBy("createdAt", "desc"), limit(12)),
    );
    const history = histSnap.docs
      .map((d) => d.data() as any)
      .reverse()
      .map((m) => `${m.role}: ${m.text}`)
      .join("\n")
      .slice(0, 6000);

    const prompt =
      `You are a helpful assistant. Answer using the document context.\n` +
      `If the context is missing, say what to upload / where to look.\n\n` +
      `Recent chat history:\n${history}\n\n` +
      `Document context:\n${context}\n\n` +
      `User question: ${qText}`;

    const result = await model.generateContent(prompt);
    const ans = result.response.text() || "No answer returned.";

    await addDoc(messagesRef(u.uid, currentDocId), {
      role: "assistant",
      text: ans,
      createdAt: serverTimestamp(),
    });
  } catch (err: any) {
    console.error(err);
    setMsg(appMsg, err?.message || "Chat failed", "error");
  }
});

function appendChatMsg(role: string, text: string) {
  const div = document.createElement("div");
  div.className = "chatmsg";
  div.innerHTML = `<span class="role">${escapeHtml(role)}:</span> ${escapeHtml(text)}`;
  chatLog.appendChild(div);
}

function pickTopChunks(queryText: string, chunks: Array<{ text: string; page: number }>, k: number) {
  const words = queryText
    .toLowerCase()
    .split(/[^a-z0-9]+/g)
    .filter((w) => w.length >= 3)
    .slice(0, 12);

  const scored = chunks.map((c) => {
    const t = c.text.toLowerCase();
    let score = 0;
    for (const w of words) {
      const m = t.match(new RegExp(`\\b${w}\\b`, "g"));
      score += m ? m.length : 0;
    }
    return { ...c, score };
  });

  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, k);
}


/* ------ CHUNKING ------ */

function chunkText(full: string, maxLen: number, overlap: number): string[] {
  const out: string[] = [];
  let start = 0;
  while (start < full.length) {
    const end = Math.min(full.length, start + maxLen);
    out.push(full.slice(start, end));
    start = end - overlap;
    if (start < 0) start = 0;
  }
  return out;
}

async function fetchChunkSample(uid: string, docId: string, takeN: number) {
  const snap = await getDocs(query(chunksRef(uid, docId), orderBy("createdAt", "asc"), limit(takeN)));
  return snap.docs
    .map((d) => (d.data() as any).text || "")
    .join("\n")
    .slice(0, 15000);
}


/* ------ UI TOGGLE FOR AUTHENTICATION STATE ------ */

onAuthStateChanged(auth, (user) => {
  setMsg(authMsg, "");
  setMsg(appMsg, "");

  if (!user) {
    userEmail.textContent = "";
    signOutBtn.classList.add("hidden");
    authCard.classList.remove("hidden");
    appCard.classList.add("hidden");

    if (unsubscribeDocs) unsubscribeDocs();
    if (unsubscribeChunks) unsubscribeChunks();
    if (unsubscribeMessages) unsubscribeMessages();

    unsubscribeDocs = unsubscribeChunks = unsubscribeMessages = null;
    currentDocId = null;
    currentChunks = [];
    return;
  }

  userEmail.textContent = user.email || "";
  signOutBtn.classList.remove("hidden");
  authCard.classList.add("hidden");
  appCard.classList.remove("hidden");

  startDocsListener(user.uid);
});
