
import React, { useState, useRef } from 'react';
import { 
  Radar, RadarChart, PolarGrid, PolarAngleAxis, ResponsiveContainer,
  AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid
} from 'recharts';
import { 
  Award, Zap, ChevronRight, Activity as ActivityIcon, Calendar, Trophy, 
  MapPin, Link as LinkIcon, Users as UsersIcon, X, Camera,
  Linkedin, Github, ExternalLink, Briefcase, Plus, Check, Search, Trash2
} from 'lucide-react';

const SKILL_DATA = [
  { subject: 'Modeling', A: 85 },
  { subject: 'Accounting', A: 60 },
  { subject: 'Valuation', A: 90 },
  { subject: 'Markets', A: 45 },
  { subject: 'Strategy', A: 70 },
  { subject: 'Presence', A: 80 },
];

const WEEKLY_XP = [
  { day: 'Mon', xp: 120 }, { day: 'Tue', xp: 250 }, { day: 'Wed', xp: 180 },
  { day: 'Thu', xp: 210 }, { day: 'Fri', xp: 320 }, { day: 'Sat', xp: 245 }, { day: 'Sun', xp: 290 },
];

const LEADERBOARD = [
  { name: 'Marcus L.', xp: '14,200', avatar: '1' },
  { name: 'Sarah J.', xp: '12,850', avatar: '2' },
  { name: 'Alex W.', xp: '12,140', avatar: '3', isUser: true },
  { name: 'David K.', xp: '11,900', avatar: '4' },
];

const SUGGESTED_ORGS = [
  { id: 'goldman', name: 'Goldman Sachs', domain: 'goldmansachs.com' },
  { id: 'mckinsey', name: 'McKinsey & Company', domain: 'mckinsey.com' },
  { id: 'google', name: 'Google', domain: 'google.com' },
  { id: 'blackstone', name: 'Blackstone', domain: 'blackstone.com' },
  { id: 'bcg', name: 'BCG', domain: 'bcg.com' },
  { id: 'morganstanley', name: 'Morgan Stanley', domain: 'morganstanley.com' },
];

const Dashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState('Overview');
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [orgSearch, setOrgSearch] = useState('');
  
  const [profileData, setProfileData] = useState({
    name: 'Alex Wilson',
    handle: '@alexw_analyst',
    bio: 'Aspiring Investment Banker | 3rd Year Finance Student.',
    location: 'Toronto, Canada',
    website: 'alexwilson.finance',
    linkedin: 'alex-wilson-analyst',
    github: 'alexw-dev',
    photo: 'https://picsum.photos/seed/user123/400/400',
    organizations: [
      { id: 'goldman', name: 'Goldman Sachs', domain: 'goldmansachs.com' },
      { id: 'mckinsey', name: 'McKinsey & Company', domain: 'mckinsey.com' }
    ]
  });

  const fileInputRef = useRef<HTMLInputElement>(null);

  const addOrg = (org: typeof SUGGESTED_ORGS[0]) => {
    if (profileData.organizations.some(o => o.id === org.id)) return;
    setProfileData({ ...profileData, organizations: [...profileData.organizations, org] });
    setOrgSearch('');
  };

  const removeOrg = (id: string) => {
    setProfileData({ ...profileData, organizations: profileData.organizations.filter(o => o.id !== id) });
  };

  const renderOverview = () => (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-3 duration-1000">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
        <div className="p-10 bg-white border border-slate-100 rounded-[2.5rem] shadow-sm hover:shadow-xl hover:shadow-slate-200/50 transition-all duration-500 group">
          <div className="flex items-center justify-between mb-10">
            <h3 className="text-[13px] font-bold text-slate-500 uppercase tracking-[0.1em]">Performance Velocity</h3>
            <div className="flex items-center gap-1.5 text-indigo-500 font-bold text-xs">
              <ActivityIcon size={14} /> +12% today
            </div>
          </div>
          <div className="h-[260px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={WEEKLY_XP}>
                <defs>
                  <linearGradient id="colorXp" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#6366f1" stopOpacity={0.1}/>
                    <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f8fafc" />
                <XAxis dataKey="day" axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#94a3b8', fontWeight: 300 }} dy={10} />
                <Tooltip 
                  contentStyle={{ borderRadius: '20px', border: 'none', padding: '12px 16px', boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.1)' }}
                  labelStyle={{ fontWeight: 600, color: '#0f172a', marginBottom: '4px' }}
                />
                <Area type="monotone" dataKey="xp" stroke="#6366f1" strokeWidth={2.5} fill="url(#colorXp)" animationDuration={2000} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="p-10 bg-white border border-slate-100 rounded-[2.5rem] shadow-sm">
          <div className="flex items-center justify-between mb-10">
            <h3 className="text-[13px] font-bold text-slate-500 uppercase tracking-[0.1em]">League Standing</h3>
            <Trophy size={16} className="text-amber-400" />
          </div>
          <div className="space-y-4">
            {LEADERBOARD.map((item, i) => (
              <div key={i} className={`flex items-center justify-between p-4 rounded-2xl transition-all duration-300 ${item.isUser ? 'bg-indigo-50/40 border border-indigo-100' : 'hover:bg-slate-50'}`}>
                <div className="flex items-center gap-4">
                  <span className={`text-xs font-black w-4 ${i < 3 ? 'text-slate-900' : 'text-slate-300'}`}>{i + 1}</span>
                  <div className="relative">
                    <img src={`https://picsum.photos/seed/${item.avatar}/80/80`} className="w-10 h-10 rounded-full border border-white shadow-sm" alt="" />
                  </div>
                  <span className={`text-[13px] font-semibold ${item.isUser ? 'text-indigo-950' : 'text-slate-700'}`}>{item.name}</span>
                </div>
                <div className="flex items-baseline gap-1">
                  <span className="text-sm font-black text-slate-900">{item.xp}</span>
                  <span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest">XP</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="p-10 bg-white border border-slate-100 rounded-[2.5rem] shadow-sm">
        <div className="flex items-center justify-between mb-10">
          <h3 className="text-[13px] font-bold text-slate-500 uppercase tracking-[0.1em]">Activity Graph</h3>
          <div className="flex items-center gap-4 text-[11px] text-slate-400 font-medium">
            <span>Low</span>
            <div className="flex gap-1.5">
              {[0, 1, 2, 3, 4].map(l => (
                <div key={l} className={`w-3.5 h-3.5 rounded-[4px] ${l === 0 ? 'bg-slate-50' : l === 1 ? 'bg-indigo-100' : l === 2 ? 'bg-indigo-300' : l === 3 ? 'bg-indigo-500' : 'bg-indigo-700'}`} />
              ))}
            </div>
            <span>High</span>
          </div>
        </div>
        <div className="flex gap-[6px] overflow-x-auto pb-4 no-scrollbar">
          {Array.from({ length: 52 }).map((_, wi) => (
            <div key={wi} className="flex flex-col gap-[6px] shrink-0">
              {Array.from({ length: 7 }).map((_, di) => {
                const level = Math.floor(Math.random() * 5);
                return (
                  <div key={di} className={`w-[15px] h-[15px] rounded-[4px] transition-all hover:ring-4 hover:ring-indigo-100 cursor-help ${
                    level === 0 ? 'bg-slate-50' : 
                    level === 1 ? 'bg-indigo-50' : 
                    level === 2 ? 'bg-indigo-200' : 
                    level === 3 ? 'bg-indigo-400' : 'bg-indigo-600'
                  }`} />
                );
              })}
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  return (
    <div className="max-w-[1400px] mx-auto animate-in fade-in duration-700">
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-20">
        
        {/* Left Sidebar Profile */}
        <div className="lg:col-span-3 space-y-12">
          <div className="flex flex-col items-center lg:items-start text-center lg:text-left">
            <div className="w-full aspect-square max-w-[280px] rounded-[3rem] border-8 border-white overflow-hidden mb-10 shadow-2xl group relative cursor-pointer" onClick={() => fileInputRef.current?.click()}>
              <img src={profileData.photo} alt="Profile" className="w-full h-full object-cover transition-transform duration-1000 group-hover:scale-105" />
              <div className="absolute inset-0 bg-slate-950/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center backdrop-blur-[2px]">
                <Camera size={32} className="text-white opacity-80" />
              </div>
              <input type="file" ref={fileInputRef} className="hidden" onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) setProfileData({ ...profileData, photo: URL.createObjectURL(file) });
              }} accept="image/*" />
            </div>
            
            <div className="w-full space-y-4">
              <h1 className="text-3xl font-black text-slate-900 tracking-tight">{profileData.name}</h1>
              <p className="text-slate-400 font-medium text-base">{profileData.handle}</p>
              
              <button 
                onClick={() => setIsEditModalOpen(true)}
                className="w-full py-3.5 bg-white border border-slate-100 text-slate-700 text-[13px] font-bold rounded-2xl hover:bg-slate-50 hover:shadow-lg hover:shadow-slate-200/50 transition-all duration-300"
              >
                Edit Profile
              </button>
              
              <p className="text-[14px] text-slate-500 leading-relaxed font-normal py-4">
                {profileData.bio}
              </p>
              
              <div className="space-y-5 w-full border-t border-slate-50 pt-8">
                <div className="flex items-center gap-3 text-[13px] text-slate-500 group">
                  <MapPin size={18} className="text-slate-300 group-hover:text-slate-500 transition-colors" />
                  <span className="font-medium">{profileData.location}</span>
                </div>
                <div className="flex items-center gap-3 text-[13px] text-slate-500 group cursor-pointer">
                  <LinkIcon size={18} className="text-slate-300 group-hover:text-indigo-500 transition-colors" />
                  <span className="font-bold underline decoration-indigo-100 underline-offset-4 group-hover:text-indigo-600 transition-colors">{profileData.website}</span>
                </div>
                <div className="flex items-center gap-3 text-[13px] text-slate-500 group cursor-pointer">
                  <Linkedin size={18} className="text-slate-300 group-hover:text-blue-600 transition-colors" />
                  <span className="font-medium group-hover:text-slate-900 transition-colors">in/{profileData.linkedin}</span>
                </div>
              </div>

              <div className="mt-12 pt-10 border-t border-slate-50 w-full">
                <h3 className="text-[10px] font-bold text-slate-300 uppercase tracking-[0.2em] mb-6">Affiliations</h3>
                <div className="flex flex-wrap gap-4">
                  {profileData.organizations.map(org => (
                    <div 
                      key={org.id} 
                      className="group relative w-12 h-12 rounded-2xl bg-white border border-slate-100 shadow-sm flex items-center justify-center p-2.5 hover:shadow-xl hover:-translate-y-1 transition-all duration-500"
                      title={org.name}
                    >
                      <img 
                        src={`https://logo.clearbit.com/${org.domain}`} 
                        alt={org.name} 
                        className="w-full h-full object-contain grayscale opacity-60 group-hover:grayscale-0 group-hover:opacity-100 transition-all duration-500"
                        onError={(e) => { (e.target as HTMLImageElement).src = `https://ui-avatars.com/api/?name=${org.name}&background=f1f5f9&color=64748b`; }}
                      />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Content Area */}
        <div className="lg:col-span-9 space-y-12">
          <div className="flex gap-12 border-b border-slate-50">
            {['Overview', 'Mock History', 'Skills', 'Activity'].map(tab => (
              <button 
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`text-[13px] pb-5 px-1 transition-all duration-300 border-b-2 font-bold tracking-tight ${
                  activeTab === tab 
                  ? 'text-slate-950 border-indigo-600' 
                  : 'text-slate-400 border-transparent hover:text-slate-600 hover:border-slate-200'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>

          <div className="min-h-[700px]">
            {activeTab === 'Overview' && renderOverview()}
            
            {activeTab === 'Skills' && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-20 items-center bg-white p-14 border border-slate-100 rounded-[3rem] shadow-sm animate-in fade-in duration-1000">
                <div className="h-[480px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <RadarChart cx="50%" cy="50%" outerRadius="80%" data={SKILL_DATA}>
                      <PolarGrid stroke="#f1f5f9" strokeWidth={1} />
                      <PolarAngleAxis dataKey="subject" tick={{ fontSize: 11, fontWeight: 700, fill: '#64748b', letterSpacing: '0.05em' }} />
                      <Radar name="Alex" dataKey="A" stroke="#6366f1" strokeWidth={3} fill="#6366f1" fillOpacity={0.08} animationBegin={300} />
                    </RadarChart>
                  </ResponsiveContainer>
                </div>
                <div className="space-y-6">
                  <h3 className="text-2xl font-black text-slate-900 mb-10 tracking-tight italic">Domain Mastery.</h3>
                  {SKILL_DATA.map(skill => (
                    <div key={skill.subject} className="group">
                      <div className="flex justify-between items-center mb-2">
                        <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{skill.subject}</span>
                        <span className="text-xs font-black text-indigo-600">{skill.A}%</span>
                      </div>
                      <div className="h-1.5 w-full bg-slate-50 rounded-full overflow-hidden border border-slate-100">
                        <div 
                          className="h-full bg-indigo-500 rounded-full transition-all duration-[1.5s] ease-out group-hover:bg-indigo-400" 
                          style={{ width: `${skill.A}%` }} 
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {activeTab === 'Mock History' && (
              <div className="space-y-6 animate-in slide-in-from-right-4 duration-700">
                {[
                  { role: 'IB Summer Analyst', firm: 'Goldman Sachs', score: 92, date: 'Oct 24, 2024', status: 'Elite' },
                  { role: 'Business Analyst', firm: 'McKinsey', score: 78, date: 'Oct 12, 2024', status: 'Passed' },
                  { role: 'Product Intern', firm: 'Google', score: 95, date: 'Sept 28, 2024', status: 'Elite' },
                ].map((mock, i) => (
                  <div key={i} className="p-10 bg-white border border-slate-100 rounded-[2.5rem] flex items-center justify-between group cursor-pointer hover:border-indigo-100 hover:shadow-2xl hover:shadow-indigo-50/50 transition-all duration-500">
                    <div className="flex items-center gap-8">
                      <div className="w-16 h-16 bg-slate-900 rounded-[1.25rem] flex items-center justify-center text-white text-xl font-black italic shadow-2xl shadow-slate-300 group-hover:scale-105 transition-transform">
                        {mock.firm[0]}
                      </div>
                      <div>
                        <h4 className="text-lg font-bold text-slate-900 tracking-tight">{mock.role}</h4>
                        <div className="flex items-center gap-3 text-slate-400 text-[11px] font-bold mt-2 uppercase tracking-[0.1em]">
                          <span className="text-indigo-500">{mock.firm}</span>
                          <span className="w-1 h-1 bg-slate-200 rounded-full" />
                          <span>{mock.date}</span>
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-12">
                      <div className="text-right">
                        <p className="text-3xl font-black text-slate-900 tracking-tighter">{mock.score}%</p>
                        <p className="text-[10px] text-slate-400 uppercase font-black tracking-[0.2em] mt-1">Accuracy</p>
                      </div>
                      <div className={`px-5 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest ${
                        mock.status === 'Elite' ? 'bg-teal-50 text-teal-600 border border-teal-100' : 'bg-indigo-50 text-indigo-600 border border-indigo-100'
                      }`}>
                        {mock.status}
                      </div>
                      <ChevronRight size={20} className="text-slate-200 group-hover:text-indigo-400 group-hover:translate-x-1 transition-all" />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Edit Modal Refined */}
      {isEditModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 backdrop-blur-xl bg-slate-950/20">
          <div className="absolute inset-0" onClick={() => setIsEditModalOpen(false)} />
          <div className="relative bg-white w-full max-w-2xl rounded-[3.5rem] shadow-[0_50px_100px_-20px_rgba(0,0,0,0.1)] p-14 animate-in zoom-in-95 duration-500 max-h-[90vh] overflow-y-auto no-scrollbar border border-slate-100">
            <button onClick={() => setIsEditModalOpen(false)} className="absolute top-10 right-10 p-3 bg-slate-50 rounded-2xl text-slate-400 hover:text-slate-950 transition-all active:scale-95">
              <X size={20} />
            </button>
            
            <h2 className="text-3xl font-black text-slate-900 mb-2 italic tracking-tight">Personal Details.</h2>
            <p className="text-slate-400 font-medium mb-12 text-sm tracking-tight">Update your recruiter-facing identity.</p>
            
            <div className="space-y-10">
              <div className="grid grid-cols-2 gap-10">
                <div className="space-y-3">
                  <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Public Name</label>
                  <input type="text" value={profileData.name} onChange={e => setProfileData({...profileData, name: e.target.value})} className="w-full p-4 bg-slate-50 border border-slate-100 rounded-2xl text-[13px] font-bold outline-none focus:ring-4 focus:ring-indigo-500/10 focus:bg-white transition-all duration-300" />
                </div>
                <div className="space-y-3">
                  <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Region</label>
                  <input type="text" value={profileData.location} onChange={e => setProfileData({...profileData, location: e.target.value})} className="w-full p-4 bg-slate-50 border border-slate-100 rounded-2xl text-[13px] font-bold outline-none focus:ring-4 focus:ring-indigo-500/10 focus:bg-white transition-all duration-300" />
                </div>
              </div>

              <div className="space-y-3">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Aura / Bio</label>
                <textarea value={profileData.bio} onChange={e => setProfileData({...profileData, bio: e.target.value})} className="w-full p-4 bg-slate-50 border border-slate-100 rounded-2xl text-[13px] font-medium outline-none focus:ring-4 focus:ring-indigo-500/10 focus:bg-white h-24 resize-none transition-all duration-300" />
              </div>

              <div className="border-t border-slate-50 pt-10">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-6 block">Organization Link</label>
                <div className="relative mb-8">
                  <Search className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                  <input 
                    type="text" 
                    placeholder="Search global companies..." 
                    value={orgSearch}
                    onChange={e => setOrgSearch(e.target.value)}
                    className="w-full pl-14 pr-6 py-4.5 bg-slate-50 border border-slate-100 rounded-2xl text-[13px] font-bold outline-none focus:bg-white focus:ring-4 focus:ring-indigo-500/10 transition-all"
                  />
                  {orgSearch && (
                    <div className="absolute top-full left-0 w-full bg-white border border-slate-100 mt-3 rounded-[2rem] shadow-2xl z-50 overflow-hidden divide-y divide-slate-50 max-h-56 overflow-y-auto no-scrollbar">
                      {SUGGESTED_ORGS.filter(o => o.name.toLowerCase().includes(orgSearch.toLowerCase())).map(org => (
                        <button key={org.id} onClick={() => addOrg(org)} className="w-full p-5 flex items-center gap-5 hover:bg-slate-50 text-left transition-colors group">
                          <img src={`https://logo.clearbit.com/${org.domain}`} className="w-9 h-9 object-contain grayscale group-hover:grayscale-0 transition-all" alt="" />
                          <span className="text-[13px] font-bold text-slate-900">{org.name}</span>
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                <div className="flex flex-wrap gap-4">
                  {profileData.organizations.map(org => (
                    <div key={org.id} className="flex items-center gap-4 p-3 pr-5 bg-white border border-slate-100 rounded-2xl shadow-sm hover:shadow-md transition-all group">
                      <img src={`https://logo.clearbit.com/${org.domain}`} className="w-8 h-8 object-contain" alt="" />
                      <span className="text-[11px] font-bold text-slate-700">{org.name}</span>
                      <button onClick={() => removeOrg(org.id)} className="p-1 text-slate-300 hover:text-red-500 transition-colors">
                        <Trash2 size={14} />
                      </button>
                    </div>
                  ))}
                </div>
              </div>

              <button 
                onClick={() => setIsEditModalOpen(false)} 
                className="w-full py-5 bg-slate-950 text-white rounded-[1.75rem] font-black text-lg hover:bg-slate-800 transition-all shadow-2xl shadow-slate-200 active:scale-[0.98] mt-4"
              >
                Save Changes.
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Dashboard;
