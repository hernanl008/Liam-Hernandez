
import { GoogleGenAI, Type } from "@google/genai";

// Use gemini-3-flash-preview for high-speed question generation
export const generateInterviewQuestion = async (role: string, type: string, company?: string) => {
  const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
  const companyPrompt = company ? ` specifically at ${company},` : "";
  const response = await ai.models.generateContent({
    model: 'gemini-3-flash-preview',
    contents: `Generate a unique, high-difficulty ${type} interview question for a ${role} position${companyPrompt}.
    Avoid clichés. The question should test first-principles thinking and deep technical or behavioral nuance.
    If it's a technical question, include a specific quantitative scenario or edge case.
    Return ONLY the question text. Ensure it is distinct from common online lists.`,
    config: {
      temperature: 0.9, // Higher temperature for "endless uniqueness"
    }
  });
  return response.text;
};

export const evaluateResponse = async (question: string, userAnswer: string) => {
  const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
  const response = await ai.models.generateContent({
    model: 'gemini-3-pro-preview',
    contents: `Interviewer Mode: Evaluate the candidate's response to: "${question}"
    Candidate Answer: "${userAnswer}"
    
    Analysis Requirements:
    - Score (0-100) based on elite firm standards.
    - Check for "Top-Down" communication, structure, and technical accuracy.
    - Identify filler words or logical fallacies.
    
    Return JSON format:`,
    config: {
      responseMimeType: "application/json",
      responseSchema: {
        type: Type.OBJECT,
        properties: {
          Score: { type: Type.NUMBER },
          StructureScore: { type: Type.NUMBER },
          TechnicalScore: { type: Type.NUMBER },
          Strengths: { type: Type.ARRAY, items: { type: Type.STRING } },
          AreasForImprovement: { type: Type.ARRAY, items: { type: Type.STRING } },
          IdealAnswerSnippet: { type: Type.STRING },
        },
        required: ["Score", "StructureScore", "TechnicalScore", "Strengths", "AreasForImprovement", "IdealAnswerSnippet"]
      }
    }
  });
  
  try {
    return JSON.parse(response.text || "{}");
  } catch (e) {
    console.error("AI Evaluation failed", e);
    return null;
  }
};

export const analyzeResume = async (resumeText: string, targetRole: string) => {
  const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
  const response = await ai.models.generateContent({
    model: 'gemini-3-pro-preview',
    contents: `Scan this resume for a ${targetRole} role. Use ATS-matching logic: "${resumeText}"`,
    config: {
      responseMimeType: "application/json",
      responseSchema: {
        type: Type.OBJECT,
        properties: {
          OverallMatch: { type: Type.NUMBER },
          MissingKeywords: { type: Type.ARRAY, items: { type: Type.STRING } },
          WeakPoints: { type: Type.ARRAY, items: { type: Type.STRING } },
          TweakedBulletPoints: { 
            type: Type.ARRAY, 
            items: { 
              type: Type.OBJECT,
              properties: {
                original: { type: Type.STRING },
                improved: { type: Type.STRING },
                reason: { type: Type.STRING }
              }
            }
          },
          ProfessionalSummaryAdvice: { type: Type.STRING }
        },
        required: ["OverallMatch", "MissingKeywords", "WeakPoints", "TweakedBulletPoints", "ProfessionalSummaryAdvice"]
      }
    }
  });
  
  try {
    return JSON.parse(response.text || "{}");
  } catch (e) {
    return null;
  }
};
