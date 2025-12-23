
import React, { useState } from 'react';
import { HashRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import TopBar from './components/TopBar';
import Dashboard from './pages/Dashboard';
import Practice from './pages/Practice';
import Simulate from './pages/Simulate';
import Community from './pages/Community';
import Learn from './pages/Learn';
import Settings from './pages/Settings';
import Resume from './pages/Resume';
import Billing from './pages/Billing';

const App: React.FC = () => {
  const [isSidebarExpanded, setIsSidebarExpanded] = useState(false);

  return (
    <Router>
      <div className="flex h-screen w-screen bg-[#F8FAFC] text-slate-900 font-light">
        {/* Sidebar */}
        <Sidebar 
          isExpanded={isSidebarExpanded} 
          setIsExpanded={setIsSidebarExpanded} 
        />

        {/* Main Content Area */}
        <main className="flex-1 flex flex-col min-w-0">
          <TopBar />
          
          <div className="flex-1 overflow-y-auto no-scrollbar p-10 lg:p-14">
            <Routes>
              <Route path="/" element={<Navigate to="/dashboard" replace />} />
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/practice" element={<Practice />} />
              <Route path="/simulate" element={<Simulate />} />
              <Route path="/community" element={<Community />} />
              <Route path="/learn" element={<Learn />} />
              <Route path="/resume" element={<Resume />} />
              <Route path="/billing" element={<Billing />} />
              <Route path="/settings" element={<Settings />} />
            </Routes>
          </div>
        </main>
      </div>
    </Router>
  );
};

export default App;
