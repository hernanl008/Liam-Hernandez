
import React, { useState } from 'react';
import { NavLink } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Target, 
  Video, 
  Users, 
  BookOpen, 
  Settings,
  ChevronRight,
  ChevronLeft,
  Command,
  FileText,
  Star,
  CreditCard
} from 'lucide-react';
import ProModal from './ProModal';

interface SidebarProps {
  isExpanded: boolean;
  setIsExpanded: (val: boolean) => void;
}

const Sidebar: React.FC<SidebarProps> = ({ isExpanded, setIsExpanded }) => {
  const [isProModalOpen, setIsProModalOpen] = useState(false);

  const navItems = [
    { icon: LayoutDashboard, label: 'Dashboard', path: '/dashboard' },
    { icon: Target, label: 'Practice', path: '/practice' },
    { icon: Video, label: 'Simulate', path: '/simulate' },
    { icon: FileText, label: 'Resume', path: '/resume' },
    { icon: Users, label: 'Community', path: '/community' },
    { icon: BookOpen, label: 'Learn', path: '/learn' },
    { icon: CreditCard, label: 'Billing', path: '/billing' },
  ];

  return (
    <>
      <aside 
        className={`relative h-screen border-r border-slate-100 bg-white transition-all duration-500 ease-[cubic-bezier(0.23,1,0.32,1)] ${
          isExpanded ? 'w-64' : 'w-20'
        } flex flex-col z-50`}
      >
        <div className="flex items-center justify-between p-6 mb-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-slate-900 flex items-center justify-center text-white shrink-0 shadow-lg shadow-slate-200">
              <Command size={20} />
            </div>
            {isExpanded && <span className="font-semibold text-lg tracking-tight">LevelUp</span>}
          </div>
        </div>

        <nav className="flex-1 px-3 space-y-2">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) => 
                `flex items-center gap-4 p-3 rounded-xl transition-all duration-300 ${
                  isActive 
                  ? 'bg-slate-50 text-slate-950 shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] border border-slate-100' 
                  : 'text-slate-400 hover:bg-slate-50 hover:text-slate-900'
                }`
              }
            >
              <item.icon size={20} className="shrink-0" strokeWidth={isActive ? 2 : 1.5} />
              {isExpanded && <span className="text-[13px] font-medium tracking-tight whitespace-nowrap">{item.label}</span>}
            </NavLink>
          ))}
        </nav>

        <div className="p-3 border-t border-slate-50 space-y-2">
          {isExpanded && (
            <button 
              onClick={() => setIsProModalOpen(true)}
              className="w-full flex items-center gap-3 p-3 rounded-xl bg-slate-900 text-white hover:bg-slate-800 transition-all mb-4 group shadow-xl shadow-slate-200"
            >
              <Star size={18} className="shrink-0 fill-indigo-400 text-indigo-400 group-hover:scale-110 transition-transform" />
              <span className="text-[11px] font-bold uppercase tracking-[0.05em]">Upgrade to Pro</span>
            </button>
          )}
          
          <NavLink
            to="/settings"
            className={({ isActive }) => 
              `flex items-center gap-4 p-3 rounded-xl transition-colors ${
                isActive 
                ? 'bg-slate-50 text-slate-900' 
                : 'text-slate-400 hover:bg-slate-50 hover:text-slate-900'
              }`
            }
          >
            <Settings size={20} className="shrink-0" strokeWidth={isActive ? 2 : 1.5} />
            {isExpanded && <span className="text-[13px] font-medium tracking-tight">Settings</span>}
          </NavLink>

          <button 
            onClick={() => setIsExpanded(!isExpanded)}
            className="w-full flex items-center gap-4 p-3 rounded-xl text-slate-400 hover:bg-slate-50 hover:text-slate-900 transition-colors"
          >
            {isExpanded ? <ChevronLeft size={20} /> : <ChevronRight size={20} />}
            {isExpanded && <span className="text-[13px] font-medium tracking-tight">Collapse</span>}
          </button>
        </div>
      </aside>

      <ProModal isOpen={isProModalOpen} onClose={() => setIsProModalOpen(false)} />
    </>
  );
};

export default Sidebar;
