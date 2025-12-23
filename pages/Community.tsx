
import React, { useState } from 'react';
import { MessageSquare, ThumbsUp, Hash, Filter, Plus, X, Send, User as UserIcon, Share2, MoreHorizontal } from 'lucide-react';

interface Post {
  id: number;
  title: string;
  body: string;
  author: string;
  time: string;
  tags: string[];
  upvotes: number;
  replies: number;
  liked?: boolean;
}

const INITIAL_POSTS: Post[] = [
  { id: 1, title: 'RBC Capital Markets Fall 2024 Interview Report', body: 'Just finished the final round at RBC. Focus was heavily on market-sizing and behavioral fit. Be prepared for questions about the specific Canadian macro environment right now.', author: 'JuniorAnalyst_99', time: '2h ago', tags: ['Investment Banking', 'Canada'], upvotes: 42, replies: 12 },
  { id: 2, title: 'Tips for handling a stressful case interview with BCG?', body: 'The interviewer really pushed me on the quantitative logic midway through. My tip: always verbalize your assumptions before you start calculation.', author: 'FutureConsultant', time: '5h ago', tags: ['Consulting', 'Behavioral'], upvotes: 128, replies: 34 },
  { id: 3, title: 'Tech PM vs Product Strategy: Salary & Progression in Toronto', body: 'Curious about the base pay for L4 equivalents at Google Canada vs startups like Wealthsimple. Anyone have internal benchmarks?', author: 'PM_Lead', time: '1d ago', tags: ['PM / Strategy', 'Canada'], upvotes: 89, replies: 56 },
];

const Community: React.FC = () => {
  const [posts, setPosts] = useState<Post[]>(INITIAL_POSTS);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [activeTab, setActiveTab] = useState('All Posts');
  const [newPost, setNewPost] = useState({ title: '', body: '', tags: '' });
  const [viewingPost, setViewingPost] = useState<Post | null>(null);

  const handleCreatePost = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPost.title.trim() || !newPost.body.trim()) return;

    const post: Post = {
      id: Date.now(),
      title: newPost.title,
      body: newPost.body,
      author: 'Alex Wilson',
      time: 'Just now',
      tags: newPost.tags.split(',').map(t => t.trim()).filter(t => t),
      upvotes: 0,
      replies: 0,
      liked: false
    };

    setPosts([post, ...posts]);
    setNewPost({ title: '', body: '', tags: '' });
    setIsModalOpen(false);
  };

  const toggleLike = (id: number) => {
    setPosts(prevPosts => prevPosts.map(p => 
      p.id === id 
        ? { ...p, upvotes: p.liked ? p.upvotes - 1 : p.upvotes + 1, liked: !p.liked } 
        : p
    ));
    // If viewing the post in modal, sync its state
    if (viewingPost && viewingPost.id === id) {
      setViewingPost(prev => prev ? { 
        ...prev, 
        upvotes: prev.liked ? prev.upvotes - 1 : prev.upvotes + 1, 
        liked: !prev.liked 
      } : null);
    }
  };

  const filteredPosts = posts.filter(p => activeTab === 'All Posts' || p.tags.includes(activeTab));

  return (
    <div className="max-w-4xl mx-auto space-y-12 animate-in fade-in duration-700 pb-20">
      <header className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-black text-slate-900 italic tracking-tight">Community Feed.</h1>
          <p className="text-slate-400 font-medium text-base mt-1 tracking-tight">Connect with {posts.length} high-performing peers.</p>
        </div>
        <button 
          onClick={() => setIsModalOpen(true)}
          className="flex items-center gap-2 px-8 py-3.5 bg-slate-950 text-white text-[13px] font-bold rounded-2xl hover:bg-slate-800 transition-all shadow-xl shadow-slate-200 active:scale-95"
        >
          <Plus size={18} /> Create Discussion
        </button>
      </header>

      <div className="flex gap-4 overflow-x-auto no-scrollbar pb-2">
        {['All Posts', 'Investment Banking', 'Consulting', 'Analytics', 'Canada', 'PM / Strategy'].map(tag => (
          <button 
            key={tag} 
            onClick={() => setActiveTab(tag)}
            className={`px-5 py-2.5 rounded-2xl text-[11px] font-black uppercase tracking-widest transition-all border ${
              activeTab === tag ? 'bg-slate-900 border-slate-900 text-white shadow-xl' : 'bg-white border-slate-100 text-slate-400 hover:border-slate-300 hover:text-slate-900'
            }`}
          >
            {tag}
          </button>
        ))}
      </div>

      <div className="space-y-6">
        {filteredPosts.map(post => (
          <div 
            key={post.id} 
            onClick={() => setViewingPost(post)}
            className="p-10 bg-white border border-slate-100 rounded-[3rem] shadow-sm hover:border-indigo-100 hover:shadow-2xl hover:shadow-indigo-50/30 transition-all duration-500 cursor-pointer group relative overflow-hidden"
          >
            <div className="flex gap-2 mb-6">
              {post.tags.map(tag => (
                <span key={tag} className="px-3 py-1 bg-indigo-50/50 text-indigo-500 rounded-lg text-[10px] font-black uppercase tracking-widest border border-indigo-100 flex items-center gap-1.5">
                  <Hash size={10} strokeWidth={3} /> {tag}
                </span>
              ))}
            </div>
            
            <h3 className="text-2xl font-black text-slate-900 group-hover:text-indigo-600 transition-colors leading-tight mb-3 tracking-tight">{post.title}</h3>
            <p className="text-[15px] text-slate-500 line-clamp-2 leading-relaxed mb-10 font-medium">{post.body}</p>
            
            <div className="flex items-center justify-between text-slate-400 border-t border-slate-50 pt-8">
              <div className="flex items-center gap-8">
                <button 
                  onClick={(e) => { e.stopPropagation(); toggleLike(post.id); }}
                  className={`flex items-center gap-2.5 text-xs font-black transition-all ${post.liked ? 'text-indigo-600 scale-105' : 'hover:text-indigo-500 hover:scale-105'}`}
                >
                  <ThumbsUp size={18} strokeWidth={post.liked ? 3 : 1.5} fill={post.liked ? "currentColor" : "none"} /> {post.upvotes}
                </button>
                <div className="flex items-center gap-2.5 text-xs font-black hover:text-slate-600 transition-colors">
                  <MessageSquare size={18} /> {post.replies}
                </div>
              </div>
              <div className="flex items-center gap-4 border-l border-slate-100 pl-8">
                <div className="text-right">
                  <p className="text-[11px] font-black text-slate-950 uppercase tracking-tighter">@{post.author}</p>
                  <p className="text-[10px] font-bold text-slate-300 uppercase tracking-widest">{post.time}</p>
                </div>
                <div className="w-10 h-10 rounded-2xl bg-slate-50 border border-slate-100 flex items-center justify-center text-slate-300 group-hover:bg-slate-900 group-hover:text-white transition-all duration-500">
                  <UserIcon size={18} />
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* New Post Modal Refined */}
      {isModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 backdrop-blur-xl bg-slate-950/20">
          <div className="absolute inset-0" onClick={() => setIsModalOpen(false)} />
          <form onSubmit={handleCreatePost} className="relative bg-white w-full max-w-xl rounded-[3.5rem] shadow-[0_50px_100px_-20px_rgba(0,0,0,0.1)] p-14 animate-in zoom-in-95 duration-500 border border-slate-100">
            <button type="button" onClick={() => setIsModalOpen(false)} className="absolute top-10 right-10 p-3 bg-slate-50 rounded-2xl text-slate-400 hover:text-slate-950 transition-all"><X size={20}/></button>
            <h2 className="text-3xl font-black text-slate-900 mb-2 italic tracking-tight">New Discussion.</h2>
            <p className="text-slate-400 font-medium mb-10 text-sm tracking-tight">Post insights or ask for interview feedback.</p>
            
            <div className="space-y-8">
              <div className="space-y-3">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">Subject</label>
                <input 
                  type="text" 
                  value={newPost.title}
                  onChange={e => setNewPost({...newPost, title: e.target.value})}
                  placeholder="e.g. My Goldman Sachs Analyst Round Experience"
                  className="w-full p-4.5 bg-slate-50 border border-slate-100 rounded-2xl text-[13px] font-bold outline-none focus:ring-4 focus:ring-indigo-500/10 focus:bg-white transition-all"
                />
              </div>
              <div className="space-y-3">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">Content</label>
                <textarea 
                  value={newPost.body}
                  onChange={e => setNewPost({...newPost, body: e.target.value})}
                  placeholder="Elaborate on the questions, vibe, and difficulty..."
                  className="w-full p-4.5 bg-slate-50 border border-slate-100 rounded-2xl text-[13px] font-medium outline-none focus:ring-4 focus:ring-indigo-500/10 focus:bg-white h-48 resize-none transition-all leading-relaxed"
                />
              </div>
              <div className="space-y-3">
                <label className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">Categories</label>
                <input 
                  type="text" 
                  value={newPost.tags}
                  onChange={e => setNewPost({...newPost, tags: e.target.value})}
                  placeholder="IB, Consulting, Strategy"
                  className="w-full p-4.5 bg-slate-50 border border-slate-100 rounded-2xl text-[13px] font-bold outline-none focus:ring-4 focus:ring-indigo-500/10 focus:bg-white transition-all"
                />
              </div>
              <button className="w-full py-5 bg-slate-950 text-white rounded-[1.75rem] font-black text-lg hover:bg-slate-800 transition-all flex items-center justify-center gap-3 active:scale-[0.98] shadow-2xl shadow-slate-200 mt-4">
                Push to Feed <Send size={20} />
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Viewing Post Modal Refined */}
      {viewingPost && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 backdrop-blur-xl bg-slate-950/20">
          <div className="absolute inset-0" onClick={() => setViewingPost(null)} />
          <div className="relative bg-white w-full max-w-2xl rounded-[3.5rem] shadow-2xl p-14 animate-in slide-in-from-bottom-6 duration-500 max-h-[90vh] overflow-y-auto no-scrollbar border border-slate-100">
            <button onClick={() => setViewingPost(null)} className="absolute top-10 right-10 p-3 bg-slate-50 rounded-2xl text-slate-400 hover:text-slate-950 transition-all"><X size={20}/></button>
            <div className="flex gap-2 mb-6">
              {viewingPost.tags.map(tag => (
                <span key={tag} className="px-4 py-1.5 bg-indigo-50 text-indigo-600 rounded-xl text-[10px] font-black uppercase tracking-widest border border-indigo-100">{tag}</span>
              ))}
            </div>
            <h1 className="text-3xl font-black text-slate-950 leading-tight mb-8 tracking-tight">{viewingPost.title}</h1>
            <div className="flex items-center gap-4 mb-12 pb-10 border-b border-slate-50">
              <div className="w-14 h-14 bg-indigo-600 rounded-2xl flex items-center justify-center text-white font-black italic shadow-xl shadow-indigo-100">
                {viewingPost.author[0]}
              </div>
              <div>
                <p className="text-base font-black text-slate-950 uppercase tracking-tighter">@{viewingPost.author}</p>
                <p className="text-xs font-bold text-slate-300 uppercase tracking-widest">{viewingPost.time}</p>
              </div>
            </div>
            <div className="mb-14">
              <p className="text-lg text-slate-700 leading-relaxed font-medium whitespace-pre-wrap">{viewingPost.body}</p>
            </div>
            <div className="flex items-center gap-10 py-8 border-t border-slate-50">
               <button onClick={() => toggleLike(viewingPost.id)} className={`flex items-center gap-3 text-sm font-black transition-all ${viewingPost.liked ? 'text-indigo-600 scale-105' : 'text-slate-400 hover:text-slate-600'}`}>
                 <ThumbsUp size={24} strokeWidth={viewingPost.liked ? 3 : 1.5} fill={viewingPost.liked ? "currentColor" : "none"} /> {viewingPost.upvotes}
               </button>
               <button className="flex items-center gap-3 text-sm font-black text-slate-400 hover:text-slate-600 transition-all">
                 <MessageSquare size={24} /> {viewingPost.replies}
               </button>
               <button className="flex items-center gap-3 text-sm font-black text-slate-300 hover:text-slate-500 ml-auto transition-all">
                 <MoreHorizontal size={24} />
               </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Community;
