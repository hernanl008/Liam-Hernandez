
import React from 'react';
import { 
  CreditCard, 
  ShieldCheck, 
  ReceiptText, 
  Download, 
  Plus, 
  Star, 
  ExternalLink,
  ChevronRight,
  TrendingUp,
  Zap
} from 'lucide-react';

const Billing: React.FC = () => {
  const invoices = [
    { id: 'INV-2024-001', date: 'Oct 01, 2024', amount: '$29.00', status: 'Paid' },
    { id: 'INV-2024-002', date: 'Sept 01, 2024', amount: '$29.00', status: 'Paid' },
    { id: 'INV-2024-003', date: 'Aug 01, 2024', amount: '$29.00', status: 'Paid' },
  ];

  return (
    <div className="max-w-[1000px] mx-auto space-y-12 animate-in fade-in duration-700 pb-20">
      <header>
        <h1 className="text-3xl font-black text-slate-900 tracking-tight italic">Billing & Plan.</h1>
        <p className="text-slate-400 font-medium text-base mt-1 tracking-tight">Manage your professional subscription and payment cycles.</p>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        {/* Active Plan Card */}
        <div className="lg:col-span-2 p-12 bg-slate-950 text-white rounded-[3rem] shadow-2xl shadow-slate-200 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-12 text-white/5 pointer-events-none group-hover:scale-110 transition-transform duration-1000">
            <Zap size={240} strokeWidth={1} />
          </div>
          <div className="relative z-10 flex flex-col h-full justify-between">
            <div>
              <div className="flex items-center gap-3 mb-10">
                <div className="px-4 py-1.5 bg-indigo-500 rounded-xl text-[10px] font-black uppercase tracking-widest shadow-xl shadow-indigo-500/30">Active Plan</div>
                <div className="flex items-center gap-1.5 text-slate-400 text-xs font-bold uppercase tracking-widest">
                  <Star size={14} className="fill-indigo-500 text-indigo-500" /> Professional
                </div>
              </div>
              <h2 className="text-4xl font-black mb-4">$29.00 <span className="text-xl text-slate-500 font-medium tracking-tight">/ month</span></h2>
              <p className="text-slate-400 text-sm max-w-sm font-medium leading-relaxed">Your next billing cycle begins on Nov 01, 2024. Your premium features are unlocked for all Tier 1 company sets.</p>
            </div>
            
            <div className="mt-12 flex gap-4">
              <button className="px-8 py-4 bg-white text-slate-950 rounded-2xl text-[13px] font-black hover:bg-slate-100 transition-all active:scale-95 shadow-xl shadow-white/5">Manage Plan</button>
              <button className="px-8 py-4 bg-slate-800 text-slate-300 rounded-2xl text-[13px] font-black hover:bg-slate-700 transition-all border border-slate-700">Cancel Plan</button>
            </div>
          </div>
        </div>

        {/* Payment Method Card */}
        <div className="p-10 bg-white border border-slate-100 rounded-[3rem] shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-10">
              <h3 className="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Payment Method</h3>
              <CreditCard size={18} className="text-slate-300" />
            </div>
            <div className="p-6 bg-slate-50 border border-slate-100 rounded-[2rem] space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-6 bg-slate-900 rounded-md" />
                <button className="text-[10px] font-bold text-indigo-600 hover:underline uppercase tracking-widest">Edit</button>
              </div>
              <div>
                <p className="text-base font-black text-slate-900 tracking-tighter">•••• •••• •••• 4242</p>
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-1">Expires 12/26</p>
              </div>
            </div>
          </div>
          <button className="w-full mt-8 py-4 border-2 border-dashed border-slate-100 rounded-[1.75rem] text-[11px] font-bold text-slate-400 hover:border-indigo-200 hover:text-indigo-500 transition-all flex items-center justify-center gap-2 uppercase tracking-widest">
            <Plus size={16} /> Add Payment Method
          </button>
        </div>
      </div>

      {/* Invoices Table */}
      <div className="bg-white border border-slate-100 rounded-[3rem] overflow-hidden shadow-sm">
        <div className="p-10 border-b border-slate-50 flex items-center justify-between">
          <h3 className="text-lg font-black text-slate-900 italic tracking-tight">Billing History.</h3>
          <button className="flex items-center gap-2 text-[11px] font-bold text-slate-400 hover:text-indigo-600 transition-colors uppercase tracking-widest">
            <ReceiptText size={16} /> Export All
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-slate-50/50">
                <th className="px-10 py-5 text-left text-[10px] font-bold text-slate-400 uppercase tracking-widest">Invoice ID</th>
                <th className="px-10 py-5 text-left text-[10px] font-bold text-slate-400 uppercase tracking-widest">Billing Date</th>
                <th className="px-10 py-5 text-left text-[10px] font-bold text-slate-400 uppercase tracking-widest">Amount</th>
                <th className="px-10 py-5 text-left text-[10px] font-bold text-slate-400 uppercase tracking-widest">Status</th>
                <th className="px-10 py-5 text-right text-[10px] font-bold text-slate-400 uppercase tracking-widest">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {invoices.map((inv) => (
                <tr key={inv.id} className="group hover:bg-slate-50/50 transition-colors">
                  <td className="px-10 py-6 text-[13px] font-bold text-slate-700">{inv.id}</td>
                  <td className="px-10 py-6 text-[13px] font-medium text-slate-500">{inv.date}</td>
                  <td className="px-10 py-6 text-[13px] font-bold text-slate-900">{inv.amount}</td>
                  <td className="px-10 py-6">
                    <span className="px-3 py-1 bg-teal-50 text-teal-600 rounded-lg text-[10px] font-bold uppercase tracking-widest border border-teal-100">
                      {inv.status}
                    </span>
                  </td>
                  <td className="px-10 py-6 text-right">
                    <button className="p-2 text-slate-300 hover:text-indigo-600 transition-colors">
                      <Download size={18} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="p-8 bg-slate-50/50 border-t border-slate-50 text-center">
          <p className="text-[11px] font-medium text-slate-400 tracking-tight flex items-center justify-center gap-2">
            <ShieldCheck size={14} className="text-teal-500" /> Your transaction history is fully encrypted and secure.
          </p>
        </div>
      </div>
    </div>
  );
};

export default Billing;
