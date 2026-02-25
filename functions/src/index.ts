import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { defineSecret } from "firebase-functions/params";

const GEMINI_KEY = defineSecret("GOOGLE_GENAI_API_KEY");

if (admin.apps.length === 0) {
    admin.initializeApp();
}

setGlobalOptions({
    maxInstances: 10,
    region: "asia-southeast1",
    memory: "1GiB",
    timeoutSeconds: 120
});

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

function pickTopChunks(queryText: string, chunks: any[], k: number) {
    const words = queryText.toLowerCase().split(/[^a-z0-9]+/g).filter((w) => w.length >= 3).slice(0, 12);
    const scored = chunks.map((c) => {
        const t = (c.text || "").toLowerCase();
        let score = 0;
        for (const w of words) {
            const m = t.match(new RegExp(`\\b${w}\\b`, "g"));
            score += m ? m.length : 0;
        }
        return { ...c, score };
    });
    return scored.sort((a: any, b: any) => b.score - a.score).slice(0, k);
}

export const onPdfUploaded = onObjectFinalized({ secrets: [GEMINI_KEY] }, async (event) => {
    const genAI = new GoogleGenerativeAI(GEMINI_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    const filePath = event.data.name;
    if (!filePath || !filePath.endsWith(".pdf")) return;

    try {
        const bucket = admin.storage().bucket(event.data.bucket);
        const [fileBuffer] = await bucket.file(filePath).download();

        const prompt = `You will receive a PDF. Return EXACTLY this format:
<SUMMARY>2-3 sentences about what the document is about.</SUMMARY>
<TEXT>All readable text in reading order.</TEXT>`;

        const result = await model.generateContent([
            prompt,
            { inlineData: { data: fileBuffer.toString("base64"), mimeType: "application/pdf" } }
        ]);

        const raw = result.response.text();
        const summary = raw.match(/<SUMMARY>([\s\S]*?)<\/SUMMARY>/i)?.[1]?.trim() || "";
        const extracted = raw.match(/<TEXT>([\s\S]*?)<\/TEXT>/i)?.[1]?.trim() || "";

        const db = admin.firestore();
        const nodes = await db.collectionGroup("nodes").where("fileUrl", "==", filePath).get();

        if (nodes.empty) return;
        const nodeDoc = nodes.docs[0];

        const chunks = extracted.length > 0 ? chunkTextSafe(extracted, 1200, 200) : ["Empty"];
        const chunkColl = nodeDoc.ref.collection("chunks");

        const batch = db.batch();
        chunks.forEach((text, i) => {
            const ref = chunkColl.doc();
            batch.set(ref, { text, createdAt: admin.firestore.FieldValue.serverTimestamp(), idx: i });
        });
        await batch.commit();

        await nodeDoc.ref.update({ summary, fullContent: extracted, status: "done" });
    } catch (err) {
        console.error("PDF Processing Error:", err);
    }
});

export const smartRecallChat = onDocumentCreated({
    document: "users/{userId}/messages/{messageId}",
    secrets: [GEMINI_KEY]
}, async (event) => {
    const data = event.data?.data();
    if (!data || data.role !== "user") return;

    try {
        const genAI = new GoogleGenerativeAI(GEMINI_KEY.value());
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        const db = admin.firestore();
        const { userId } = event.params;

        const chunkSnap = await db.collectionGroup("chunks").get();
        const currentChunks = chunkSnap.docs
            .filter(doc => doc.ref.path.includes(`users/${userId}`))
            .map(d => d.data());

        const top = pickTopChunks(data.text, currentChunks, 6);
        const context = top.map((c) => `Content: ${c.text}`).join("\n---\n");

        const histSnap = await db.collection(`users/${userId}/messages`)
            .orderBy("createdAt", "desc")
            .limit(5)
            .get();

        const history = histSnap.docs
            .map(d => d.data())
            .reverse()
            .map(m => `${m.role}: ${m.text}`)
            .join("\n");

        const prompt = `You are Cognistore AI. Use the context to answer. 
        If not found, say it's not in your memory bank.
        
        History: ${history}
        Context: ${context}
        User: ${data.text}`;

        const result = await model.generateContent(prompt);

        await event.data?.ref.parent.add({
            role: "assistant",
            text: result.response.text(),
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

    } catch (err) {
        console.error("Recall Chat Error:", err);
    }
});
