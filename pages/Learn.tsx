
import React, { useState } from 'react';
import { BookOpen, Star, Clock, Trophy, PlayCircle, Search, Filter, CheckCircle, X, ChevronRight, Award } from 'lucide-react';

interface Module {
  title: string;
  duration: string;
  xp: number;
  category: string;
  content: string[];
}

const RAW_MODULES: Module[] = [
  { title: 'The Three Statements', duration: '12 min', xp: 150, category: 'Accounting', content: ['Understanding Income Statement', 'Balance Sheet Mechanics', 'Cash Flow Statement Foundations', 'The Integration Points'] },
  { title: 'DCF Fundamentals', duration: '20 min', xp: 250, category: 'Valuation', content: ['Intrinsic vs Relative Valuation', 'FCF Projection Logic', 'WACC Calculation', 'Terminal Value Concepts'] },
  { title: 'WACC Deep Dive', duration: '18 min', xp: 210, category: 'Valuation', content: ['Cost of Equity (CAPM)', 'Cost of Debt', 'Tax Shield Impact', 'Capital Structure Weights'] },
  { title: 'Capital Markets 101', duration: '15 min', xp: 180, category: 'Markets', content: ['Primary vs Secondary Markets', 'Equity (ECM) vs Debt (DCM)', 'Sales & Trading roles', 'Underwriting Basics'] },
  { title: 'M&A Deal Lifecycle', duration: '25 min', xp: 300, category: 'Strategy', content: ['Strategic Rationale', 'Accretion/Dilution Analysis', 'Due Diligence Process', 'Integration Strategy'] },
];

const Learn: React.FC = () => {
  const [activeTab, setActiveTab] = useState('All');
  const [search, setSearch] = useState('');
  const [completedModules, setCompletedModules] = useState<Set<string>>(new Set());
  const [activeLesson, setActiveLesson] = useState<Module | null>(null);
  const [lessonStep, setLessonStep] = useState(0);

  const filtered = RAW_MODULES.filter(m => 
    (activeTab === 'All' || m.category === activeTab) &&
    (m.title.toLowerCase().includes(search.toLowerCase()) || m.category.toLowerCase().includes(search.toLowerCase()))
  );

  const handleCompleteStep = () => {
    if (!activeLesson) return;
    if (lessonStep < activeLesson.content.length - 1) {
      setLessonStep(prev => prev + 1);
    } else {
      const newCompleted = new Set(completedModules);
      newCompleted.add(activeLesson.title);
      setCompletedModules(newCompleted);
      // Simulate XP Gain
      alert(`Lesson Complete! You earned ${activeLesson.xp} XP and a streak boost!`);
      setActiveLesson(null);
      setLessonStep(0);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8 animate-in fade-in duration-500 pb-20">
      <header className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight italic">Knowledge Hub.</h1>
          <p className="text-slate-500 text-sm mt-1">Master elite concepts across {RAW_MODULES.length} modules.</p>
        </div>
        <div className="flex gap-2 w-full md:w-auto">
          <div className="relative flex-1 md:w-64">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
            <input 
              type="text" 
              placeholder="Search concepts..." 
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 bg-white border border-[#E5E7EB] rounded-xl text-sm font-bold outline-none focus:ring-4 focus:ring-indigo-500/10 transition-all"
            />
          </div>
          <button className="p-2.5 border border-[#E5E7EB] bg-white rounded-xl text-slate-500 hover:text-slate-900 transition-colors">
            <Filter size={20} />
          </button>
        </div>
      </header>

      <section className="p-10 bg-slate-900 rounded-[2.5rem] text-white relative overflow-hidden shadow-2xl shadow-indigo-100">
        <div className="relative z-10 max-w-lg">
          <span className="inline-block px-3 py-1 bg-indigo-500 text-white rounded-lg text-[10px] font-black uppercase tracking-[0.2em] mb-4">Trending Module</span>
          <h2 className="text-3xl font-black mb-2 italic">Advanced LBO Modeling.</h2>
          <p className="text-slate-400 text-sm leading-relaxed mb-8">
            Go beyond the basics. Learn complex debt schedules, PIK interest, and dividend recaps as seen in Tier 1 Private Equity interviews.
          </p>
          <button 
            onClick={() => alert('Starting LBO Module...')}
            className="px-8 py-3 bg-white text-slate-900 text-sm font-black rounded-[1rem] hover:bg-slate-100 hover:scale-105 transition-all flex items-center gap-2 shadow-xl"
          >
            Start Module <PlayCircle size={18} />
          </button>
        </div>
        <div className="absolute -bottom-20 -right-20 text-white/5 pointer-events-none">
          <Trophy size={400} />
        </div>
      </section>

      <div className="flex items-center gap-3 overflow-x-auto no-scrollbar py-2">
        {['All', 'Accounting', 'Valuation', 'Markets', 'Strategy'].map(cat => (
          <button
            key={cat}
            onClick={() => setActiveTab(cat)}
            className={`px-6 py-2.5 rounded-xl text-xs font-black uppercase tracking-widest border transition-all whitespace-nowrap ${
              activeTab === cat 
              ? 'bg-slate-900 border-slate-900 text-white shadow-xl translate-y-[-2px]' 
              : 'bg-white border-slate-200 text-slate-500 hover:border-slate-400'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filtered.map((mod, idx) => (
          <div 
            key={idx} 
            onClick={() => { setActiveLesson(mod); setLessonStep(0); }}
            className="p-6 bg-white border border-[#E5E7EB] rounded-[2rem] flex items-center justify-between group hover:border-indigo-400 hover:shadow-2xl transition-all cursor-pointer shadow-sm relative overflow-hidden active:scale-95"
          >
            <div className="space-y-1 pr-4">
              <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{mod.category}</span>
              <h4 className="text-lg font-black text-slate-900 line-clamp-1 group-hover:text-indigo-600 transition-colors">{mod.title}</h4>
              <div className="flex items-center gap-3 text-xs font-bold text-slate-400 pt-2">
                <span className="flex items-center gap-1.5"><Clock size={14} /> {mod.duration}</span>
                <span className="flex items-center gap-1.5 text-amber-600"><Star size={14} className="fill-amber-600" /> {mod.xp} XP</span>
              </div>
            </div>
            <div className={`shrink-0 w-12 h-12 rounded-2xl border flex items-center justify-center transition-all ${
              completedModules.has(mod.title) 
              ? 'bg-teal-500 text-white border-teal-500 shadow-lg shadow-teal-100' 
              : 'bg-slate-50 text-slate-300 border-slate-100 group-hover:bg-slate-900 group-hover:text-white group-hover:border-slate-900 group-hover:shadow-xl'
            }`}>
              {completedModules.has(mod.title) ? <CheckCircle size={24} /> : <PlayCircle size={24} />}
            </div>
          </div>
        ))}
      </div>

      {/* Lesson Player Modal */}
      {activeLesson && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-slate-900/80 backdrop-blur-xl" onClick={() => setActiveLesson(null)} />
          <div className="relative bg-white w-full max-w-3xl rounded-[3rem] shadow-2xl p-12 animate-in zoom-in-95 duration-500 max-h-[90vh] overflow-hidden flex flex-col">
            <button onClick={() => setActiveLesson(null)} className="absolute top-10 right-10 p-3 bg-slate-50 rounded-full text-slate-400 hover:text-slate-900 transition-all"><X size={24}/></button>
            
            <div className="flex-1 flex flex-col">
              <div className="mb-10">
                <span className="text-[10px] font-black text-indigo-600 uppercase tracking-[0.2em] mb-4 block">{activeLesson.category}</span>
                <h2 className="text-3xl font-black text-slate-900 mb-2 italic">{activeLesson.title}</h2>
                <div className="flex gap-2 h-1.5 w-full bg-slate-100 rounded-full overflow-hidden mt-6">
                  {activeLesson.content.map((_, i) => (
                    <div key={i} className={`flex-1 transition-all duration-500 ${i <= lessonStep ? 'bg-indigo-600' : 'bg-slate-200'}`} />
                  ))}
                </div>
              </div>

              <div className="flex-1 overflow-y-auto no-scrollbar space-y-8 py-4">
                <div className="p-8 bg-slate-50 border border-slate-100 rounded-[2rem] animate-in slide-in-from-bottom-4 duration-500">
                  <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-6 flex items-center gap-2">
                    <Award size={16} className="text-indigo-500" /> Lesson {lessonStep + 1}
                  </h3>
                  <h4 className="text-2xl font-black text-slate-900 mb-4">{activeLesson.content[lessonStep]}</h4>
                  <p className="text-lg text-slate-600 leading-relaxed font-medium">
                    This module covers the core logic required to excel in professional interviews. Pay close attention to the structural links between concepts.
                  </p>
                </div>
                
                <div className="space-y-4">
                  <p className="text-sm font-bold text-slate-400 uppercase tracking-widest">Key Takeaways</p>
                  <ul className="space-y-3">
                    {['Understand the first-principles logic.', 'Apply to real-world datasets.', 'Structure for top-down communication.'].map((item, i) => (
                      <li key={i} className="flex items-center gap-3 text-slate-700 font-bold">
                        <div className="w-2 h-2 rounded-full bg-indigo-500" /> {item}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              <div className="mt-10 pt-8 border-t border-slate-100 flex justify-between items-center">
                <p className="text-xs font-bold text-slate-400 uppercase tracking-widest">Step {lessonStep + 1} of {activeLesson.content.length}</p>
                <button 
                  onClick={handleCompleteStep}
                  className="px-10 py-4 bg-slate-900 text-white rounded-2xl font-black text-lg hover:bg-indigo-600 transition-all flex items-center gap-3 shadow-2xl active:scale-95"
                >
                  {lessonStep === activeLesson.content.length - 1 ? 'Finish & Earn XP' : 'Next Step'} <ChevronRight size={20} />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Learn;
