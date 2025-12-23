
import React from 'react';
import { X, Check, Zap, Shield, Star, Globe } from 'lucide-react';

interface ProModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const ProModal: React.FC<ProModalProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm" onClick={onClose} />
      <div className="relative bg-white w-full max-w-2xl rounded-3xl shadow-2xl overflow-hidden animate-in zoom-in-95 duration-300">
        <button 
          onClick={onClose}
          className="absolute top-4 right-4 p-2 text-slate-400 hover:text-slate-900 transition-colors"
        >
          <X size={20} />
        </button>

        <div className="grid grid-cols-1 md:grid-cols-2">
          <div className="p-8 bg-slate-900 text-white flex flex-col justify-between">
            <div>
              <div className="w-12 h-12 bg-indigo-500 rounded-2xl flex items-center justify-center mb-6 shadow-lg shadow-indigo-500/20">
                <Star size={24} fill="white" />
              </div>
              <h2 className="text-2xl font-bold mb-2">LevelUp Pro</h2>
              <p className="text-slate-400 text-sm leading-relaxed">
                The ultimate toolkit for aspiring analysts and consultants. Outperform the competition with AI-driven precision.
              </p>
            </div>

            <div className="mt-8 space-y-4">
              <div className="flex items-center gap-3 text-sm">
                <div className="w-5 h-5 rounded-full bg-indigo-500/20 flex items-center justify-center">
                  <Check size={12} className="text-indigo-400" />
                </div>
                Unlimited AI Mock Interviews
              </div>
              <div className="flex items-center gap-3 text-sm">
                <div className="w-5 h-5 rounded-full bg-indigo-500/20 flex items-center justify-center">
                  <Check size={12} className="text-indigo-400" />
                </div>
                Deep Resume Keyword Injection
              </div>
              <div className="flex items-center gap-3 text-sm">
                <div className="w-5 h-5 rounded-full bg-indigo-500/20 flex items-center justify-center">
                  <Check size={12} className="text-indigo-400" />
                </div>
                Premium MBB & Bulge Bracket Sets
              </div>
              <div className="flex items-center gap-3 text-sm">
                <div className="w-5 h-5 rounded-full bg-indigo-500/20 flex items-center justify-center">
                  <Check size={12} className="text-indigo-400" />
                </div>
                Private Community Mastermind
              </div>
            </div>
          </div>

          <div className="p-8 flex flex-col justify-center bg-white">
            <div className="mb-8">
              <span className="text-slate-500 text-sm font-medium">Billed annually</span>
              <div className="flex items-baseline gap-1 mt-1">
                <span className="text-4xl font-bold text-slate-900">$29</span>
                <span className="text-slate-500">/mo</span>
              </div>
            </div>

            <div className="space-y-3 mb-8">
              <button className="w-full py-3 bg-indigo-600 text-white rounded-xl font-semibold hover:bg-indigo-700 transition-all shadow-lg shadow-indigo-200">
                Upgrade Now
              </button>
              <p className="text-[10px] text-slate-400 text-center">
                7-day money back guarantee. Cancel anytime.
              </p>
            </div>

            <div className="grid grid-cols-2 gap-4 border-t border-slate-100 pt-6">
              <div className="flex flex-col items-center text-center">
                <Shield size={20} className="text-slate-300 mb-2" />
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-tighter">Secure Payment</span>
              </div>
              <div className="flex flex-col items-center text-center">
                <Globe size={20} className="text-slate-300 mb-2" />
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-tighter">Global Access</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ProModal;
