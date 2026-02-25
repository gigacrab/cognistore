import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCallGenkit } from "firebase-functions/https";
import { defineSecret } from "firebase-functions/params";
import { genkit, z } from "genkit";
import { googleAI } from "@genkit-ai/google-genai";

const apiKey = defineSecret("GOOGLE_GENAI_API_KEY");

if (admin.apps.length === 0) {
    admin.initializeApp();
}

const ai = genkit({
    plugins: [googleAI()],
});

setGlobalOptions({
    maxInstances: 10,
    region: "asia-southeast1",
    memory: "1GiB",
    timeoutSeconds: 120
});

export const aiSummaryFlow = ai.defineFlow({
    name: "aiSummaryFlow",
    inputSchema: z.string().describe("Full extracted PDF text").default("nothing"),
    outputSchema: z.string(),
}, async (extractedText) => {
    const prompt = `
      You are a highly intelligent corporate assistant. Please read the following document text and provide a concise, 2-sentence summary of the main decisions, trade-offs, or insights.
        
      Document Text:
      ${extractedText}
    `;
    const response = await ai.generate({
        // FIX 1: Upgraded to the active 2.5 model
        model: googleAI.model("gemini-2.5-flash"), 
        prompt: prompt,
    });
    return response.text;
});

export const generateSummary = onCallGenkit({
    authPolicy: (auth) => !!auth?.uid,
    secrets: [apiKey],
}, aiSummaryFlow);

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

export const onNodeCreated = onDocumentCreated({
    document: "users/{userId}/nodes/{nodeId}",
}, async (event) => {
    const data = event.data?.data();
    if (!data || !data.fullContent) return; 

    try {
        const db = admin.firestore();
        const chunks = chunkTextSafe(data.fullContent, 1200, 200);
        const batch = db.batch();

        chunks.forEach((text, i) => {
            const ref = event.data!.ref.collection("chunks").doc();
            batch.set(ref, { text, createdAt: admin.firestore.FieldValue.serverTimestamp(), idx: i });
        });

        await batch.commit();
    } catch (err) {
        console.error("Chunk Creation Error:", err);
    }
});

export const smartRecallChat = onDocumentCreated({
    document: "users/{userId}/messages/{messageId}",
    secrets: [apiKey]
}, async (event) => {
    console.log("🔥 [SmartRecall] Triggered!");

    const data = event.data?.data();
    if (!data || data.role !== "user") {
        return;
    }

    try {
        const db = admin.firestore();
        const { userId } = event.params;
        console.log(`👤 [SmartRecall] Processing request for User ID: ${userId}`);

        const nodesSnap = await db.collection('users').doc(userId).collection('nodes').get();
        let allChunks: any[] = [];
        
        for (const nodeDoc of nodesSnap.docs) {
            const chunksSnap = await nodeDoc.ref.collection('chunks').get();
            allChunks.push(...chunksSnap.docs.map(d => d.data()));
        }

        console.log(`✅ [SmartRecall] Total chunks collected: ${allChunks.length}`);

        let context = "No documents found.";
        if (allChunks.length > 0) {
            const top = pickTopChunks(data.text, allChunks, 6);
            context = top.map((c) => c.text).join("\n---\n");
        }

        console.log("🤖 [SmartRecall] Sending prompt to Genkit...");
        const result = await ai.generate({
            // FIX 2: Upgraded to the active 2.5 model
            model: googleAI.model("gemini-2.5-flash"),
            prompt: `You are Cognistore AI. Use the provided context to answer the user's question. If the context is empty or the answer isn't there, politely say you don't know based on the uploaded documents.\n\nContext: ${context}\n\nUser: ${data.text}`
        });

        console.log("✅ [SmartRecall] Received response! Writing to Firestore...");
        await event.data?.ref.parent.add({
            role: "assistant",
            text: result.text,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log("🎉 [SmartRecall] Success!");

    } catch (err) {
        console.error("🚨 [SmartRecall] CRITICAL ERROR:", err);
    }
});