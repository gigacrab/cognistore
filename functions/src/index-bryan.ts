import {setGlobalOptions} from "firebase-functions";
import {genkit, z} from "genkit";
import {googleAI} from "@genkit-ai/google-genai";

// Cloud Functions for Firebase supports Genkit natively. The onCallGenkit function creates a callable
// function from a Genkit action. It automatically implements streaming if your flow does.
// The https library also has other utility methods such as hasClaim, which verifies that
// a caller's token has a specific claim (optionally matching a specific value)
import { onCallGenkit } from "firebase-functions/https";

// Gemini Developer API models and Vertex Express Mode models depend on an API key.
// API keys should be stored in Cloud Secret Manager so that access to these
// sensitive values can be controlled. defineSecret does this for you automatically.
// If you are using Google Developer API (googleAI) you can get an API key at https://aistudio.google.com/app/apikey
// If you are using Vertex Express Mode (vertexAI with apiKey) you can get an API key
// from the Vertex AI Studio Express Mode setup.
import { defineSecret } from "firebase-functions/params";

// use the command below to provide the key
// firebase functions:secrets:set GOOGLE_GENAI_API_KEY
// make sure you're logged in and have selected the project and all that
// you'd be prompted to enter the API key, do so
// ok it appears it's stored in Google servers when I ran it so we don't have to worry about it anymore
const apiKey = defineSecret("GOOGLE_GENAI_API_KEY");
setGlobalOptions({ maxInstances: 10 });

const ai = genkit({
  plugins: [
    // Load the GoogleAI provider. You can optionally specify your API key by
    // passing in a config object; if you don't, the provider uses the value
    // from the GOOGLE_GENAI_API_KEY environment variable, which is the
    // recommended practice.
    googleAI()
  ],
});

// Define a simple flow that prompts an LLM to generate menu suggestions.
const aiSummaryFlow = ai.defineFlow({
    name: "aiSummaryFlow",
    // IO schemas, basically defines input parameters and return values
    // negating the need to perform manual type checks
    inputSchema: z.string().describe("Full extracted PDF text").default("nothing"),
    outputSchema: z.string(),
    // subject is the validated input, while sendChunk is the streaming function
  }, async (extractedText) => {
    // Construct a request and send it to the model API.
    const prompt = `
      You are a highly intelligent corporate assistant. Please read the following document text and provide a concise, 2-sentence summary of the main decisions, trade-offs, or insights.
        
      Document Text:
      ${extractedText}
      `;
    // Generate without streaming
    const response = await ai.generate({
      model: googleAI.model("gemini-2.5-flash"),
      prompt: prompt,
    });

    // more complex workflows are present when the output isn't just a string
    // but may be fed into another LLM model, who knows

    // response resolves when the generation is complete, we wait for it
    // .text extracts the full final output string which matches the schema!
    return response.text;
  }
);

export const generateSummary = onCallGenkit({
  // Uncomment to enable AppCheck. This can reduce costs by ensuring only your Verified
  // app users can use your API. Read more at https://firebase.google.com/docs/app-check/cloud-functions
  //enforceAppCheck: true,

  // authPolicy can be any callback that accepts an AuthData (a uid and tokens dictionary) and the
  // request data. The isSignedIn() and hasClaim() helpers can be used to simplify. The following
  // will require the user to have the email_verified claim, for example.
  // authPolicy: hasClaim("email_verified"),
  authPolicy: (auth) => !!auth?.uid,

  // Grant access to the API key to this function:
  secrets: [apiKey],
}, aiSummaryFlow);