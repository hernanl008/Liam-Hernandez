
import React, { useState, useRef } from 'react';
import { 
  FileText, 
  Sparkles, 
  ChevronRight, 
  CheckCircle2, 
  AlertCircle,
  Copy,
  Plus,
  Upload,
  Lock,
  Search,
  Star
} from 'lucide-react';
import { analyzeResume } from '../services/gemini';
import ProModal from '../components/ProModal';

const Resume: React.FC = () => {
  const [resumeText, setResumeText] = useState("");
  const [targetRole, setTargetRole] = useState("Investment Banking Analyst");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [isProModalOpen, setIsProModalOpen] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const isPro = false; // Simulated user tier

  const handleAnalyze = async () => {
    if (!resumeText.trim()) return;
    setLoading(true);
    try {
      const data = await analyzeResume(resumeText, targetRole);
      setResult(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const text = e.target?.result as string;
        setResumeText(text);
      };
      reader.readAsText(file);
    }
  };

  const onDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const onDragLeave = () => {
    setIsDragging(false);
  };

  const onDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const text = e.target?.result as string;
        setResumeText(text);
      };
      reader.readAsText(file);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8 animate-in fade-in duration-500 pb-20">
      <header className="flex justify-between items-start">
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">Resume Strategy</h1>
          <p className="text-slate-500 text-sm mt-1">AI-powered analysis to beat Applicant Tracking Systems (ATS).</p>
        </div>
        {!isPro && (
          <button 
            onClick={() => setIsProModalOpen(true)}
            className="flex items-center gap-2 px-3 py-1 bg-amber-50 text-amber-700 rounded-lg text-xs font-bold border border-amber-100 hover:bg-amber-100 transition-all"
          >
            <Star size={14} className="fill-amber-500 text-amber-500" /> UPGRADE FOR FULL REFINEMENT
          </button>
        )}
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Left: Editor & Dropzone */}
        <div className="space-y-6">
          <div className="bg-white border border-[#E5E7EB] rounded-2xl shadow-sm overflow-hidden flex flex-col h-[650px]">
            <div className="p-4 border-b border-[#E5E7EB] bg-slate-50/50 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <FileText size={16} className="text-slate-400" />
                <span className="text-xs font-bold text-slate-700 uppercase tracking-widest">Editor</span>
              </div>
              <div className="flex items-center gap-2">
                <select 
                  value={targetRole}
                  onChange={(e) => setTargetRole(e.target.value)}
                  className="text-xs font-semibold bg-white border border-[#E5E7EB] px-2 py-1 rounded outline-none"
                >
                  <option>Investment Banking Analyst</option>
                  <option>Product Manager</option>
                  <option>Software Engineer</option>
                  <option>Management Consultant</option>
                  <option>Private Equity Associate</option>
                </select>
                <button 
                  onClick={() => setResumeText("")}
                  className="text-[10px] font-bold text-slate-400 hover:text-red-500 uppercase tracking-widest px-2"
                >
                  Clear
                </button>
              </div>
            </div>

            {!resumeText ? (
              <div 
                onDragOver={onDragOver}
                onDragLeave={onDragLeave}
                onDrop={onDrop}
                className={`flex-1 flex flex-col items-center justify-center p-8 transition-all border-2 border-dashed mx-4 my-4 rounded-3xl ${
                  isDragging ? 'bg-indigo-50 border-indigo-400' : 'bg-slate-50 border-slate-200'
                }`}
              >
                <div className="w-16 h-16 bg-white rounded-2xl flex items-center justify-center text-slate-400 shadow-sm mb-4">
                  <Upload size={32} />
                </div>
                <h3 className="text-sm font-semibold text-slate-900">Drag & Drop Resume</h3>
                <p className="text-xs text-slate-400 mt-2 max-w-[240px] text-center">
                  Drop your resume (TXT format) or click to browse.
                </p>
                <button 
                  onClick={() => fileInputRef.current?.click()}
                  className="mt-6 px-6 py-2 bg-slate-900 text-white rounded-xl text-xs font-semibold hover:bg-slate-800 transition-all"
                >
                  Browse Files
                </button>
                <input 
                  type="file" 
                  ref={fileInputRef} 
                  className="hidden" 
                  onChange={handleFileUpload} 
                  accept=".txt"
                />
              </div>
            ) : (
              <textarea 
                value={resumeText}
                onChange={(e) => setResumeText(e.target.value)}
                placeholder="Paste your resume content here..."
                className="flex-1 p-6 text-sm text-slate-600 font-mono leading-relaxed outline-none resize-none no-scrollbar bg-slate-50/30"
              />
            )}

            <div className="p-4 border-t border-[#E5E7EB] bg-slate-50/50">
              <button 
                onClick={handleAnalyze}
                disabled={loading || !resumeText.trim()}
                className="w-full py-3 bg-slate-900 text-white rounded-xl font-semibold flex items-center justify-center gap-2 hover:bg-slate-800 transition-all disabled:opacity-50"
              >
                {loading ? "Analyzing Context..." : "Run ATS Performance Scan"} <Sparkles size={16} />
              </button>
            </div>
          </div>
        </div>

        {/* Right: Results & Pro Gating */}
        <div className="space-y-6 overflow-y-auto no-scrollbar h-[650px] pb-10">
          {!result && !loading ? (
            <div className="h-full space-y-6">
              <div className="p-10 bg-white border border-[#E5E7EB] border-dashed rounded-3xl flex flex-col items-center justify-center text-center">
                 <div className="w-16 h-16 bg-indigo-50 rounded-full flex items-center justify-center text-indigo-500 mb-6">
                    <Search size={32} />
                 </div>
                 <h3 className="text-lg font-bold text-slate-900">Ready for Scan</h3>
                 <p className="text-sm text-slate-500 mt-2 max-w-sm">We'll check for keyword density, formatting errors, and role-specific impact.</p>
              </div>

              {/* Pro Feature Teaser */}
              <div className="p-6 bg-slate-900 text-white rounded-3xl relative overflow-hidden group">
                <div className="absolute top-0 right-0 p-4 text-indigo-500 opacity-20 group-hover:opacity-40 transition-opacity">
                   <Lock size={64} />
                </div>
                <div className="relative z-10">
                  <div className="flex items-center gap-2 text-indigo-400 mb-2">
                    <Star size={14} fill="currentColor" />
                    <span className="text-[10px] font-bold uppercase tracking-widest">Pro Feature</span>
                  </div>
                  <h3 className="text-lg font-bold mb-2">Technical Keyword Injection</h3>
                  <p className="text-sm text-slate-400 mb-6 leading-relaxed">
                    Our AI scans current market trends to inject high-impact terminology into your experience section.
                  </p>
                  <button 
                    onClick={() => setIsProModalOpen(true)}
                    className="px-4 py-2 bg-indigo-600 rounded-lg text-xs font-bold hover:bg-indigo-700 transition-colors"
                  >
                    Unlock Premium Insights
                  </button>
                </div>
              </div>
            </div>
          ) : loading ? (
            <div className="h-full flex flex-col items-center justify-center space-y-4">
              <div className="w-10 h-10 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
              <p className="text-xs font-bold text-slate-400 uppercase tracking-widest animate-pulse">Running Neural ATS Simulator...</p>
            </div>
          ) : (
            <div className="space-y-6 animate-in slide-in-from-right-4 duration-500">
              <div className="p-6 bg-white border border-[#E5E7EB] rounded-2xl shadow-sm text-center relative overflow-hidden">
                <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500" />
                <h4 className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Overall ATS Compliance</h4>
                <div className="text-6xl font-black text-slate-900 my-4">{result.OverallMatch}%</div>
                <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden mt-4">
                  <div className="h-full bg-indigo-500 transition-all duration-1000 ease-out" style={{ width: `${result.OverallMatch}%` }} />
                </div>
                <p className="text-[10px] text-slate-400 mt-4 font-bold uppercase tracking-tighter">Matched against 5,200 successful {targetRole} resumes</p>
              </div>

              {/* Pro Content Refinement section gated */}
              <div className="p-6 bg-slate-900 text-white rounded-3xl space-y-6 relative overflow-hidden">
                {!isPro && (
                  <div className="absolute inset-0 z-20 bg-slate-900/90 backdrop-blur-[2px] flex flex-col items-center justify-center p-8 text-center">
                    <div className="w-12 h-12 bg-indigo-500/20 rounded-2xl flex items-center justify-center text-indigo-400 mb-4 border border-indigo-500/30">
                      <Lock size={24} />
                    </div>
                    <h4 className="text-lg font-bold mb-2">Refine Your Content</h4>
                    <p className="text-xs text-slate-400 mb-6 max-w-[240px]">
                      LevelUp Pro users get AI-optimized bullet points specifically tailored for {targetRole} roles.
                    </p>
                    <button 
                      onClick={() => setIsProModalOpen(true)}
                      className="px-6 py-2 bg-indigo-600 rounded-xl text-xs font-bold hover:bg-indigo-700 transition-all flex items-center gap-2"
                    >
                      <Star size={14} fill="currentColor" /> Upgrade to View
                    </button>
                  </div>
                )}
                
                <div className="flex items-center justify-between">
                  <h4 className="text-[10px] font-bold text-indigo-400 uppercase tracking-widest flex items-center gap-2">
                    <Sparkles size={12} fill="currentColor" /> Smart Content Refinement
                  </h4>
                </div>
                <div className="space-y-6 blur-sm pointer-events-none opacity-20">
                  {/* Mock content for teaser */}
                  <div className="space-y-3 border-l-2 border-white/5 pl-4">
                    <div className="text-[11px] text-slate-500 italic opacity-60 font-mono">"Managed team of 5."</div>
                    <div className="p-4 bg-white/5 border border-white/10 rounded-2xl text-sm font-medium">
                      Spearheaded a cross-functional squad of 5 high-performers...
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-6 bg-white border border-[#E5E7EB] rounded-2xl shadow-sm">
                <h4 className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-4">Hard-Skill Gaps Identified</h4>
                <div className="flex flex-wrap gap-2">
                  {result.MissingKeywords.map((kw: string) => (
                    <span key={kw} className="px-3 py-1 bg-red-50 text-red-600 rounded-full text-[10px] font-bold border border-red-100 uppercase tracking-tight flex items-center gap-1">
                      <Plus size={10} /> {kw}
                    </span>
                  ))}
                </div>
              </div>

              <div className="p-6 bg-indigo-50/50 border border-indigo-100 rounded-2xl">
                <h4 className="text-[10px] font-bold text-indigo-500 uppercase tracking-widest mb-2 flex items-center gap-2">
                  <AlertCircle size={12} /> Executive Summary Pivot
                </h4>
                <p className="text-sm text-indigo-900 leading-relaxed font-semibold">
                  {result.ProfessionalSummaryAdvice}
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
      <ProModal isOpen={isProModalOpen} onClose={() => setIsProModalOpen(false)} />
    </div>
  );
};

export default Resume;
