
import React, { useState, useEffect } from 'react';
import { 
  Square, Mic, ChevronRight, AlertCircle, CheckCircle2, Award,
  ArrowRight, Video, Lock, Star, Timer, Briefcase, RefreshCw
} from 'lucide-react';
import { generateInterviewQuestion, evaluateResponse } from '../services/gemini';
import ProModal from '../components/ProModal';

type SimStep = 'setup' | 'interview' | 'feedback' | 'limit';

const COMPANIES = [
  "Goldman Sachs", "McKinsey & Co", "Google", "JP Morgan", "BCG", "Morgan Stanley", "BlackRock", "Amazon"
];

const Simulate: React.FC = () => {
  const [step, setStep] = useState<SimStep>('setup');
  const [loading, setLoading] = useState(false);
  const [question, setQuestion] = useState("");
  const [userAnswer, setUserAnswer] = useState("");
  const [feedback, setFeedback] = useState<any>(null);
  const [timer, setTimer] = useState(0);
  const [isRecording, setIsRecording] = useState(false);
  const [isProModalOpen, setIsProModalOpen] = useState(false);

  // Setup options
  const [role, setRole] = useState("Investment Banking Analyst");
  const [type, setType] = useState("Technical");
  const [company, setCompany] = useState("Goldman Sachs");
  const [duration, setDuration] = useState(20);
  const [autoGenerate, setAutoGenerate] = useState(true);

  const isPro = true; // Simulated Pro User

  useEffect(() => {
    let interval: any;
    if (isRecording) {
      interval = setInterval(() => setTimer(t => t + 1), 1000);
    } else {
      clearInterval(interval);
    }
    return () => clearInterval(interval);
  }, [isRecording]);

  const startSimulation = async () => {
    setLoading(true);
    try {
      const q = await generateInterviewQuestion(role, type, company);
      setQuestion(q || "Could you walk me through the key drivers of a 3-statement financial model, and specifically how a change in inventory affects cash flows?");
      setStep('interview');
      setTimer(0);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const finishInterview = async () => {
    if (!userAnswer.trim()) return;
    setLoading(true);
    try {
      const result = await evaluateResponse(question, userAnswer);
      setFeedback(result);
      setStep('feedback');
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setStep('setup');
    setUserAnswer("");
    setQuestion("");
    setFeedback(null);
    setTimer(0);
    setIsRecording(false);
  };

  if (step === 'setup') {
    return (
      <div className="max-w-3xl mx-auto py-12 space-y-8 animate-in fade-in duration-700">
        <div className="text-center">
          <div className="w-16 h-16 bg-slate-900 rounded-2xl flex items-center justify-center text-white mx-auto mb-6 shadow-xl shadow-slate-200">
            <Video className="w-8 h-8" />
          </div>
          <h1 className="text-3xl font-bold text-slate-900">Endless AI Simulations</h1>
          <p className="text-slate-500 mt-2">Pulling from 10k+ real interview patterns from global firms.</p>
        </div>

        <div className="bg-white p-8 border border-[#E5E7EB] rounded-3xl shadow-sm space-y-6">
          <div className="grid grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Target Role</label>
              <select value={role} onChange={e => setRole(e.target.value)} className="w-full p-3 bg-slate-50 border border-[#E5E7EB] rounded-xl outline-none focus:ring-2 focus:ring-indigo-500/10 text-sm font-semibold">
                <option>Investment Banking Analyst</option>
                <option>Strategy Consultant</option>
                <option>Product Manager</option>
                <option>Equity Researcher</option>
              </select>
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Company Focus</label>
              <select value={company} onChange={e => setCompany(e.target.value)} className="w-full p-3 bg-slate-50 border border-[#E5E7EB] rounded-xl outline-none focus:ring-2 focus:ring-indigo-500/10 text-sm font-semibold">
                {COMPANIES.map(c => <option key={c}>{c}</option>)}
              </select>
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Simulation Mode</label>
            <div className="grid grid-cols-4 gap-3">
              {['Technical', 'Behavioral', 'Case', 'Mixed'].map(t => (
                <button key={t} onClick={() => setType(t)} className={`p-3 text-[10px] font-bold rounded-xl border transition-all uppercase tracking-widest ${type === t ? 'bg-slate-900 border-slate-900 text-white shadow-lg' : 'bg-white border-[#E5E7EB] text-slate-500 hover:border-slate-400'}`}>
                  {t}
                </button>
              ))}
            </div>
          </div>

          <div className="pt-6 border-t border-slate-100 flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2">
                <Timer size={14} className="text-slate-400" />
                <span className="text-xs font-bold text-slate-700">{duration}m Session</span>
              </div>
              <div className="flex items-center gap-2">
                <RefreshCw size={14} className="text-indigo-400" />
                <span className="text-xs font-bold text-indigo-500">Auto-Generate Active</span>
              </div>
            </div>
            <button 
              onClick={startSimulation}
              disabled={loading}
              className="px-8 py-3 bg-slate-900 text-white rounded-2xl font-bold flex items-center gap-2 hover:bg-slate-800 transition-all disabled:opacity-50"
            >
              {loading ? "Generating Unique Context..." : "Begin Mock Session"} <ArrowRight size={18} />
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (step === 'interview') {
    return (
      <div className="max-w-4xl mx-auto h-full flex flex-col gap-6 animate-in slide-in-from-right-4 duration-500">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="px-3 py-1 bg-red-50 text-red-600 rounded-full text-[10px] font-black border border-red-100 flex items-center gap-2 animate-pulse">
              <div className="w-2 h-2 bg-red-600 rounded-full" /> LIVE {company.toUpperCase()} SESSION
            </div>
            <span className="text-slate-400 text-sm font-mono bg-white px-2 py-0.5 rounded-lg border">
              {Math.floor(timer / 60)}:{(timer % 60).toString().padStart(2, '0')}
            </span>
          </div>
          <button onClick={reset} className="text-xs font-bold text-slate-400 hover:text-red-500 transition-colors uppercase tracking-widest">Terminate Session</button>
        </div>

        <div className="flex-1 bg-white border border-[#E5E7EB] rounded-3xl shadow-2xl overflow-hidden flex flex-col glass">
          <div className="p-10 border-b border-[#E5E7EB] bg-slate-50/50">
            <div className="flex items-center gap-2 mb-4">
              <Briefcase size={16} className="text-slate-400" />
              <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Question #1</span>
            </div>
            <p className="text-2xl font-medium text-slate-900 leading-relaxed italic pr-12">"{question}"</p>
          </div>

          <div className="flex-1 p-10 relative flex flex-col">
            <textarea 
              value={userAnswer}
              onChange={(e) => setUserAnswer(e.target.value)}
              placeholder="Start speaking or type your response here. Use bulleted logic if needed..."
              className="w-full flex-1 bg-transparent resize-none outline-none text-slate-700 leading-relaxed text-xl no-scrollbar font-medium"
            />
            <div className="absolute bottom-10 right-10 flex items-center gap-4">
              <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900 text-white text-[10px] font-bold uppercase tracking-widest transition-all ${isRecording ? 'opacity-100 scale-100' : 'opacity-0 scale-90'}`}>
                <div className="w-2 h-2 bg-red-500 rounded-full animate-ping" /> Listening...
              </div>
              <button 
                onClick={() => setIsRecording(!isRecording)}
                className={`w-16 h-16 rounded-full flex items-center justify-center transition-all ${
                  isRecording ? 'bg-red-500 text-white shadow-xl shadow-red-200' : 'bg-slate-100 text-slate-400 hover:bg-slate-200 shadow-sm'
                }`}
              >
                {isRecording ? <Square size={28} fill="white" /> : <Mic size={28} />}
              </button>
            </div>
          </div>

          <div className="p-8 bg-slate-50 border-t border-[#E5E7EB] flex justify-between items-center">
            <p className="text-xs text-slate-400 font-medium">Auto-saving response draft...</p>
            <button 
              onClick={finishInterview}
              disabled={loading || !userAnswer.trim()}
              className="px-10 py-4 bg-slate-900 text-white rounded-2xl font-bold hover:bg-slate-800 transition-all disabled:opacity-50 flex items-center gap-2 shadow-xl shadow-slate-200"
            >
              {loading ? "Neural Evaluation Active..." : "Finalize & Analyze"} <ChevronRight size={18} />
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (step === 'feedback') {
    return (
      <div className="max-w-4xl mx-auto space-y-8 animate-in zoom-in-95 duration-700 pb-20">
        <header className="flex justify-between items-end">
          <div>
            <span className="text-[10px] font-black text-indigo-600 uppercase tracking-widest">Mock #42 - {company}</span>
            <h1 className="text-4xl font-black text-slate-900 mt-1 italic">Executive Report.</h1>
          </div>
          <button onClick={reset} className="px-10 py-3 bg-slate-900 text-white rounded-2xl font-bold hover:bg-slate-800 transition-all shadow-lg">New Session</button>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="p-8 bg-white border border-[#E5E7EB] rounded-3xl shadow-sm text-center space-y-2 relative overflow-hidden group">
            <div className="absolute top-0 left-0 w-full h-1.5 bg-indigo-600" />
            <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Placement Odds</h4>
            <div className="text-6xl font-black text-slate-900">{feedback?.Score || 0}%</div>
            <p className="text-xs font-bold text-slate-500 mt-2 uppercase tracking-tight">Tier 1 Target Firm</p>
          </div>
          <div className="p-8 bg-white border border-[#E5E7EB] rounded-3xl shadow-sm space-y-4">
            <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest text-center">Structure</h4>
            <div className="flex items-center justify-between text-lg font-black italic">
              <span className="text-slate-500">logic.</span>
              <span>{feedback?.StructureScore || 0}/10</span>
            </div>
            <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
              <div className="h-full bg-indigo-500 transition-all duration-1000" style={{ width: `${(feedback?.StructureScore || 0) * 10}%` }} />
            </div>
          </div>
          <div className="p-8 bg-white border border-[#E5E7EB] rounded-3xl shadow-sm space-y-4">
            <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest text-center">Accuracy</h4>
            <div className="flex items-center justify-between text-lg font-black italic">
              <span className="text-slate-500">truth.</span>
              <span>{feedback?.TechnicalScore || 0}/10</span>
            </div>
            <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
              <div className="h-full bg-teal-500 transition-all duration-1000" style={{ width: `${(feedback?.TechnicalScore || 0) * 10}%` }} />
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="space-y-4">
            <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest flex items-center gap-2">Strengths Identified</h3>
            <div className="space-y-3">
              {feedback?.Strengths?.map((s: string, i: number) => (
                <div key={i} className="p-5 bg-white border border-slate-200 rounded-2xl text-sm text-slate-700 font-bold border-l-4 border-l-teal-500 shadow-sm">{s}</div>
              ))}
            </div>
          </div>
          <div className="space-y-4">
            <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest flex items-center gap-2">Improvement Vector</h3>
            <div className="space-y-3">
              {feedback?.AreasForImprovement?.map((s: string, i: number) => (
                <div key={i} className="p-5 bg-white border border-slate-200 rounded-2xl text-sm text-slate-700 font-bold border-l-4 border-l-amber-500 shadow-sm">{s}</div>
              ))}
            </div>
          </div>
        </div>

        <div className="p-10 bg-slate-900 text-white rounded-[40px] space-y-6 shadow-2xl shadow-indigo-100/50 relative overflow-hidden">
          <div className="absolute top-0 right-0 p-10 text-white/5"><Award size={180} /></div>
          <div className="relative z-10">
            <h3 className="text-[10px] font-black text-indigo-400 uppercase tracking-[0.2em] mb-4">Interviewer's Model Answer</h3>
            <p className="text-2xl font-medium italic opacity-90 leading-relaxed max-w-2xl">"{feedback?.IdealAnswerSnippet}"</p>
          </div>
        </div>
      </div>
    );
  }

  return null;
};

export default Simulate;
