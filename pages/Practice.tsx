
import React, { useState } from 'react';
import { Search, Filter, Timer, CheckCircle2, ChevronRight, BookOpen } from 'lucide-react';

const CATEGORIES = ['All', 'IB', 'Consulting', 'Tech PM', 'Accounting', 'Valuation'];

const DRILLS = [
  { id: 1, title: 'WACC Mechanics', category: 'Valuation', level: 2, count: 12, time: '15 min' },
  { id: 2, title: '3-Statement Links', category: 'Accounting', level: 3, count: 15, time: '20 min' },
  { id: 3, title: 'Market Sizing Essentials', category: 'Consulting', level: 1, count: 8, time: '10 min' },
  { id: 4, title: 'LBO Paper Modeling', category: 'IB', level: 3, count: 10, time: '25 min' },
  { id: 5, title: 'Behavioral: Fit Pack', category: 'All', level: 1, count: 20, time: '15 min' },
  { id: 6, title: 'Metrics Case Study', category: 'Tech PM', level: 2, count: 5, time: '30 min' },
];

const Practice: React.FC = () => {
  const [activeTab, setActiveTab] = useState('All');

  return (
    <div className="max-w-6xl mx-auto space-y-6 animate-in slide-in-from-bottom-2 duration-500">
      <header className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-slate-900">Focused Practice</h1>
          <p className="text-slate-500 text-sm mt-1">Hone specific skills with bite-sized drills.</p>
        </div>
        <div className="flex gap-2 w-full md:w-auto">
          <div className="flex-1 md:w-64 relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search topics..." 
              className="w-full pl-9 pr-4 py-2 text-sm border border-[#E5E7EB] rounded-lg outline-none focus:ring-2 focus:ring-indigo-500/20"
            />
          </div>
          <button className="px-3 py-2 border border-[#E5E7EB] rounded-lg hover:bg-slate-50 text-slate-600 transition-colors">
            <Filter size={16} />
          </button>
        </div>
      </header>

      {/* Category Pills */}
      <div className="flex items-center gap-2 overflow-x-auto no-scrollbar py-2">
        {CATEGORIES.map(cat => (
          <button
            key={cat}
            onClick={() => setActiveTab(cat)}
            className={`px-4 py-1.5 rounded-full text-xs font-medium border transition-all whitespace-nowrap ${
              activeTab === cat 
              ? 'bg-slate-900 border-slate-900 text-white' 
              : 'bg-white border-[#E5E7EB] text-slate-600 hover:border-slate-400'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {/* Drills Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {DRILLS.filter(d => activeTab === 'All' || d.category === activeTab).map(drill => (
          <div 
            key={drill.id} 
            className="group p-5 bg-white border border-[#E5E7EB] rounded-2xl shadow-sm hover:shadow-md hover:border-slate-300 transition-all cursor-pointer relative overflow-hidden"
          >
            <div className="absolute top-0 right-0 p-4 opacity-0 group-hover:opacity-100 transition-opacity">
              <ChevronRight size={20} className="text-indigo-600" />
            </div>
            
            <div className="flex items-center justify-between mb-4">
              <span className="px-2 py-1 bg-slate-50 text-slate-500 rounded text-[10px] font-bold uppercase tracking-wider">
                {drill.category}
              </span>
              <div className="flex items-center gap-1 text-[10px] font-bold text-amber-600 uppercase">
                <CheckCircle2 size={12} /> Level {drill.level}
              </div>
            </div>

            <h3 className="text-base font-semibold text-slate-900 mb-2">{drill.title}</h3>
            
            <div className="flex items-center gap-4 text-slate-500 text-xs mt-6">
              <div className="flex items-center gap-1.5">
                <BookOpen size={14} />
                {drill.count} Questions
              </div>
              <div className="flex items-center gap-1.5">
                <Timer size={14} />
                {drill.time}
              </div>
            </div>

            <div className="mt-4 h-1 w-full bg-slate-100 rounded-full overflow-hidden">
              <div className="h-full bg-indigo-500 w-[40%] rounded-full" />
            </div>
            <p className="text-[10px] text-slate-400 mt-2 font-medium">40% COMPLETED</p>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Practice;
