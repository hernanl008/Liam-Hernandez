
import React from 'react';
import { User, Shield, Bell, Monitor, CreditCard } from 'lucide-react';

const Settings: React.FC = () => {
  return (
    <div className="max-w-2xl mx-auto space-y-8 animate-in fade-in duration-500">
      <header>
        <h1 className="text-2xl font-semibold text-slate-900">Settings</h1>
        <p className="text-slate-500 text-sm mt-1">Manage your account and preferences.</p>
      </header>

      <div className="space-y-6">
        <section className="bg-white border border-[#E5E7EB] rounded-2xl shadow-sm overflow-hidden">
          <div className="p-4 border-b border-[#E5E7EB] bg-slate-50/50 flex items-center gap-2">
            <User size={16} className="text-slate-400" />
            <h3 className="text-sm font-semibold text-slate-700">Profile</h3>
          </div>
          <div className="p-6 space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-xs font-bold text-slate-400 uppercase">Target Role</label>
                <input type="text" className="w-full p-2 bg-slate-50 border border-[#E5E7EB] rounded-lg text-sm outline-none focus:ring-2 focus:ring-slate-900/5" defaultValue="Investment Banking Analyst" />
              </div>
              <div className="space-y-2">
                <label className="text-xs font-bold text-slate-400 uppercase">Graduation Year</label>
                <input type="text" className="w-full p-2 bg-slate-50 border border-[#E5E7EB] rounded-lg text-sm outline-none focus:ring-2 focus:ring-slate-900/5" defaultValue="2026" />
              </div>
            </div>
            <div className="space-y-2">
              <label className="text-xs font-bold text-slate-400 uppercase">Region</label>
              <input type="text" className="w-full p-2 bg-slate-50 border border-[#E5E7EB] rounded-lg text-sm outline-none focus:ring-2 focus:ring-slate-900/5" defaultValue="Canada (Ontario)" />
            </div>
          </div>
        </section>

        <section className="bg-white border border-[#E5E7EB] rounded-2xl shadow-sm overflow-hidden">
          <div className="p-4 border-b border-[#E5E7EB] bg-slate-50/50 flex items-center gap-2">
            <Monitor size={16} className="text-slate-400" />
            <h3 className="text-sm font-semibold text-slate-700">Appearance</h3>
          </div>
          <div className="p-6 flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-900">Theme</p>
              <p className="text-xs text-slate-500">Choose between light, dark, or system preference.</p>
            </div>
            <div className="flex bg-slate-100 p-1 rounded-lg">
              <button className="px-3 py-1 bg-white shadow-sm rounded-md text-xs font-semibold text-slate-900">Light</button>
              <button className="px-3 py-1 text-xs font-semibold text-slate-500 hover:text-slate-700">Dark</button>
              <button className="px-3 py-1 text-xs font-semibold text-slate-500 hover:text-slate-700">System</button>
            </div>
          </div>
        </section>

        <section className="bg-white border border-[#E5E7EB] rounded-2xl shadow-sm overflow-hidden">
          <div className="p-4 border-b border-[#E5E7EB] bg-slate-50/50 flex items-center gap-2">
            <Shield size={16} className="text-slate-400" />
            <h3 className="text-sm font-semibold text-slate-700">Privacy & Security</h3>
          </div>
          <div className="p-6 space-y-4">
            <div className="flex items-center justify-between">
              <p className="text-sm font-medium text-slate-900">AI Personalization</p>
              <div className="w-10 h-5 bg-indigo-600 rounded-full relative">
                <div className="absolute right-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow-sm" />
              </div>
            </div>
            <div className="flex items-center justify-between">
              <p className="text-sm font-medium text-slate-900">Public Profile</p>
              <div className="w-10 h-5 bg-slate-200 rounded-full relative">
                <div className="absolute left-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow-sm" />
              </div>
            </div>
          </div>
        </section>

        <button className="w-full py-3 bg-red-50 text-red-600 rounded-xl text-sm font-semibold border border-red-100 hover:bg-red-100 transition-colors">
          Sign Out
        </button>
      </div>
    </div>
  );
};

export default Settings;
