
import React, { useState } from 'react';
/* Added Trophy to the import list from lucide-react */
import { Flame, Star, Search, Bell, ShieldCheck, X, Zap, Award, Trophy } from 'lucide-react';

const TopBar: React.FC = () => {
  const [showNotis, setShowNotis] = useState(false);
  const [notis, setNotis] = useState([
    { id: 1, title: 'Interview Feedback', body: 'Mock #42 (BCG Case) feedback is ready.', type: 'feedback', time: '5m' },
    { id: 2, title: 'League Promotion', body: 'You moved to #1 in Emerald League!', type: 'league', time: '1h' },
    { id: 3, title: 'Quest Complete', body: 'Daily 500 XP goal achieved.', type: 'quest', time: '3h' },
  ]);

  return (
    <header className="h-16 border-b border-[#E5E7EB] bg-white/80 backdrop-blur-md flex items-center justify-between px-6 sticky top-0 z-40">
      <div className="flex items-center gap-4 bg-slate-50 px-3 py-1.5 rounded-lg border border-[#E5E7EB] w-96 group transition-all focus-within:ring-2 focus-within:ring-indigo-500/10 focus-within:w-[450px]">
        <Search size={16} className="text-slate-400 group-focus-within:text-slate-600" />
        <input 
          type="text" 
          placeholder="Search for companies, skills, or drills (⌘K)" 
          className="bg-transparent text-sm w-full outline-none text-slate-600 placeholder:text-slate-400"
        />
        <span className="text-[10px] font-mono border border-slate-300 rounded px-1.5 text-slate-400 group-focus-within:hidden">⌘K</span>
      </div>

      <div className="flex items-center gap-6">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-1.5 px-3 py-1 bg-orange-50 text-orange-600 rounded-full border border-orange-100 hover:bg-orange-100 transition-colors cursor-help" title="Consecutive Practice Days">
            <Flame size={14} className="fill-orange-600" />
            <span className="text-xs font-bold">12</span>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1 bg-indigo-50 text-indigo-600 rounded-full border border-indigo-100 hover:bg-indigo-100 transition-colors cursor-help" title="Total Experience Points">
            <Star size={14} className="fill-indigo-600" />
            <span className="text-xs font-bold">1.2k</span>
          </div>
        </div>
        
        <div className="relative">
          <button 
            onClick={() => setShowNotis(!showNotis)}
            className={`p-2 rounded-lg transition-colors relative ${showNotis ? 'bg-slate-100 text-slate-900' : 'text-slate-500 hover:text-slate-900'}`}
          >
            <Bell size={20} />
            <div className="absolute top-1.5 right-1.5 w-2 h-2 bg-indigo-600 rounded-full border-2 border-white"></div>
          </button>

          {showNotis && (
            <div className="absolute top-12 right-0 w-80 bg-white border border-[#E5E7EB] rounded-2xl shadow-2xl animate-in fade-in slide-in-from-top-2 duration-200">
              <div className="p-4 border-b border-[#E5E7EB] flex items-center justify-between">
                <span className="text-xs font-bold text-slate-900 uppercase tracking-widest">Notifications</span>
                <button onClick={() => setShowNotis(false)} className="text-slate-400 hover:text-slate-600"><X size={14}/></button>
              </div>
              <div className="max-h-96 overflow-y-auto divide-y divide-[#E5E7EB]">
                {notis.map(n => (
                  <div key={n.id} className="p-4 hover:bg-slate-50 transition-colors cursor-pointer group">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-[10px] font-black text-indigo-600 uppercase tracking-tighter flex items-center gap-1">
                        {n.type === 'feedback' && <Award size={10} />}
                        {n.type === 'league' && <Trophy size={10} />}
                        {n.type === 'quest' && <Zap size={10} />}
                        {n.title}
                      </span>
                      <span className="text-[10px] text-slate-400">{n.time} ago</span>
                    </div>
                    <p className="text-xs text-slate-600 leading-tight group-hover:text-slate-900 transition-colors">{n.body}</p>
                  </div>
                ))}
              </div>
              <div className="p-3 text-center border-t border-[#E5E7EB]">
                <button className="text-[10px] font-bold text-slate-400 hover:text-indigo-600 uppercase tracking-widest">Mark all as read</button>
              </div>
            </div>
          )}
        </div>

        <div className="flex items-center gap-3 pl-4 border-l border-[#E5E7EB]">
          <div className="flex flex-col items-end">
            <span className="text-xs font-bold text-slate-900 leading-tight">Alex Wilson</span>
            <div className="flex items-center gap-1 text-[10px] font-bold text-indigo-600 uppercase tracking-widest">
              <ShieldCheck size={10} /> Pro Member
            </div>
          </div>
          <div className="w-8 h-8 rounded-full bg-slate-200 border border-[#E5E7EB] overflow-hidden">
            <img src="https://picsum.photos/seed/user123/32/32" alt="Avatar" />
          </div>
        </div>
      </div>
    </header>
  );
};

export default TopBar;
