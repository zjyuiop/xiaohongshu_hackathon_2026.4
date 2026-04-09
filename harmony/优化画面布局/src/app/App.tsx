import React, { useState } from 'react';
import { 
  Users, 
  MessageCircle,
  Plus, 
  ArrowRight,
  MoreHorizontal,
  Clock,
  UserPlus,
  Compass,
  Sparkles,
  Wind,
  Layers,
  BookOpen
} from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('arena');

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-slate-800 flex justify-center font-sans overflow-hidden selection:bg-blue-100">
      
      {/* --- Clear & Fresh Ambient Background (晨风与清透感) --- */}
      <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden bg-gradient-to-br from-[#F8FAFC] to-[#F1F5F9]">
        {/* Soft Teal/Mint */}
        <div className="absolute top-[-5%] left-[-10%] w-[400px] h-[400px] bg-teal-100/50 rounded-full blur-[100px] animate-[pulse_10s_ease-in-out_infinite]" />
        {/* Soft Indigo/Periwinkle */}
        <div className="absolute top-[20%] right-[-10%] w-[500px] h-[500px] bg-indigo-100/50 rounded-full blur-[120px] animate-[pulse_12s_ease-in-out_infinite_reverse]" />
        {/* Soft Peach/Rose */}
        <div className="absolute bottom-[-10%] left-[20%] w-[600px] h-[600px] bg-rose-50/60 rounded-full blur-[130px] animate-[pulse_14s_ease-in-out_infinite]" />
      </div>

      <div className="w-full max-w-md relative min-h-screen flex flex-col z-10">
        
        {/* Main Content Area */}
        <div className="flex-1 pb-28 overflow-y-auto custom-scrollbar px-6">
          {activeTab === 'roles' && <RolesTab />}
          {activeTab === 'arena' && <ArenaTab />}
          {activeTab === 'records' && <RecordsTab />}
        </div>

        {/* Bottom Navigation - Clean & Floating iOS Style */}
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 w-[calc(100%-3rem)] max-w-[calc(28rem-3rem)] z-50">
          <div className="bg-white/70 backdrop-blur-2xl border border-white rounded-[2rem] p-2.5 flex justify-between items-center shadow-[0_8px_30px_rgba(0,0,0,0.04)]">
            
            <NavButton 
              isActive={activeTab === 'roles'} 
              onClick={() => setActiveTab('roles')}
              icon={<Users className="w-[22px] h-[22px]" />}
              label="角色"
            />
            <NavButton 
              isActive={activeTab === 'arena'} 
              onClick={() => setActiveTab('arena')}
              icon={<Wind className="w-[22px] h-[22px]" />}
              label="共振"
            />
            <NavButton 
              isActive={activeTab === 'records'} 
              onClick={() => setActiveTab('records')}
              icon={<BookOpen className="w-[22px] h-[22px]" />}
              label="纪要"
            />
            
          </div>
        </div>

      </div>
    </div>
  );
}

function NavButton({ isActive, onClick, icon, label }: { isActive: boolean, onClick: () => void, icon: React.ReactNode, label: string }) {
  return (
    <button 
      onClick={onClick}
      className={`flex-1 flex flex-col items-center justify-center gap-1.5 py-2.5 rounded-[1.5rem] transition-all duration-500 relative group ${
        isActive ? 'text-indigo-600' : 'text-slate-400 hover:text-slate-600'
      }`}
    >
      {isActive && (
        <div className="absolute inset-0 bg-indigo-50/50 rounded-[1.5rem] scale-100 transition-transform duration-500" />
      )}
      <div className={`relative z-10 transition-transform duration-500 ${isActive ? 'scale-110 drop-shadow-sm' : 'group-hover:scale-110'}`}>
        {icon}
      </div>
      <span className={`text-[10px] font-bold tracking-wider relative z-10 transition-opacity duration-300 ${isActive ? 'opacity-100' : 'opacity-80'}`}>{label}</span>
    </button>
  );
}

// --- TAB 1: 角色库 (Roles) ---
function RolesTab() {
  return (
    <div className="pt-14 animate-in fade-in slide-in-from-bottom-4 duration-700 ease-out">
      <div className="mb-8 pl-2">
        <h1 className="text-[28px] font-bold tracking-tight text-slate-800">时序人格</h1>
        <p className="text-indigo-500/75 text-xs font-medium italic tracking-[0.2em] mt-1">Chronological Persona</p>
        <p className="text-slate-500 text-sm mt-2 font-medium">收集与创造多元的思想切片</p>
      </div>

      {/* Action Cards - Clean Soft UI */}
      <div className="grid grid-cols-2 gap-4 mb-10">
        <ClearCard className="p-5 flex flex-col items-start gap-4 group cursor-pointer hover:bg-white/80 transition-colors">
          <div className="w-12 h-12 rounded-[1rem] bg-indigo-50/80 border border-indigo-100 flex items-center justify-center text-indigo-500 group-hover:scale-105 transition-transform duration-500 shadow-sm">
            <UserPlus className="w-[22px] h-[22px]" />
          </div>
          <div>
            <h3 className="font-bold text-slate-800 text-[14px] mb-1">创造新识</h3>
            <p className="text-[12px] text-slate-500 leading-relaxed">定义一个全新的人格</p>
          </div>
        </ClearCard>
        
        <ClearCard className="p-5 flex flex-col items-start gap-4 group cursor-pointer hover:bg-white/80 transition-colors">
          <div className="w-12 h-12 rounded-[1rem] bg-teal-50/80 border border-teal-100 flex items-center justify-center text-teal-500 group-hover:scale-105 transition-transform duration-500 shadow-sm">
            <Compass className="w-[22px] h-[22px]" />
          </div>
          <div>
            <h3 className="font-bold text-slate-800 text-[14px] mb-1">寻访前人</h3>
            <p className="text-[12px] text-slate-500 leading-relaxed">导入已有的人物传记</p>
          </div>
        </ClearCard>
      </div>

      <div className="flex items-center gap-3 mb-5 pl-2">
        <h2 className="text-[11px] font-bold text-slate-400 tracking-widest uppercase">已收集的切片 (3)</h2>
        <div className="h-[1px] flex-1 bg-gradient-to-r from-slate-200 to-transparent" />
      </div>
      
      <div className="space-y-3.5">
        {/* Character Card 1 */}
        <ClearCard className="p-4 flex items-center gap-4 hover:shadow-md transition-shadow cursor-pointer group">
          <div className="w-[46px] h-[46px] rounded-full bg-gradient-to-tr from-blue-100 to-indigo-50 border border-white flex items-center justify-center font-bold text-[16px] text-indigo-600 shadow-sm">
            乔
          </div>
          <div className="flex-1 min-w-0">
            <h3 className="font-bold text-slate-800 text-[15px] truncate">乔布斯</h3>
            <p className="text-[12px] text-slate-500 truncate mt-0.5">从反叛青年到产品偏执狂</p>
          </div>
          <button className="text-slate-300 hover:text-slate-600 transition-colors p-2">
            <MoreHorizontal className="w-5 h-5" />
          </button>
        </ClearCard>

        {/* Character Card 2 */}
        <ClearCard className="p-4 flex items-center gap-4 hover:shadow-md transition-shadow cursor-pointer group">
          <div className="w-[46px] h-[46px] rounded-full bg-gradient-to-tr from-orange-50 to-rose-50 border border-white flex items-center justify-center font-bold text-[16px] text-rose-500 shadow-sm">
            秦
          </div>
          <div className="flex-1 min-w-0">
            <h3 className="font-bold text-slate-800 text-[15px] truncate">秦始皇</h3>
            <p className="text-[12px] text-slate-500 truncate mt-0.5">从少年君主到一统天下</p>
          </div>
          <button className="text-slate-300 hover:text-slate-600 transition-colors p-2">
            <MoreHorizontal className="w-5 h-5" />
          </button>
        </ClearCard>

        {/* Character Card 3 */}
        <ClearCard className="p-4 flex items-center gap-4 hover:shadow-md transition-shadow cursor-pointer group">
          <div className="w-[46px] h-[46px] rounded-full bg-white border border-slate-100 flex items-center justify-center font-bold text-[16px] text-slate-600 shadow-sm">
            我
          </div>
          <div className="flex-1 min-w-0">
            <h3 className="font-bold text-slate-800 text-[15px] truncate">普通人</h3>
            <p className="text-[12px] text-slate-500 truncate mt-0.5">在关系、工作和自我认同之间摇摆</p>
          </div>
          <button className="text-slate-300 hover:text-slate-600 transition-colors p-2">
            <MoreHorizontal className="w-5 h-5" />
          </button>
        </ClearCard>
      </div>
    </div>
  );
}

// --- TAB 2: 共振 (Arena - Agent Fusion & Chat) ---
function ArenaTab() {
  return (
    <div className="pt-14 animate-in fade-in slide-in-from-bottom-4 duration-700 ease-out">
      <div className="mb-8 pl-2">
        <h1 className="text-[28px] font-bold tracking-tight text-slate-800">思维共振</h1>
        <p className="text-slate-500 text-sm mt-2 font-medium">重组思想切片，开启多维度的对话</p>
      </div>

      {/* Agent Fusion Section - Clean & Ethereal */}
      <ClearCard className="p-6 mb-6 relative overflow-hidden">
        {/* Soft background glow for the fusion area */}
        <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-50/80 rounded-full blur-[30px]" />
        
        <div className="flex items-center justify-between mb-8 relative z-10">
          <h2 className="font-bold text-slate-800 flex items-center gap-2 text-[14px]">
            <Layers className="w-[18px] h-[18px] text-indigo-400" />
            人格编织 <span className="text-slate-400 font-normal text-xs ml-1">(Agent A)</span>
          </h2>
          <span className="text-[10px] font-bold tracking-wider text-indigo-500 bg-indigo-50 border border-indigo-100/50 px-2.5 py-1 rounded-full">
            编织中
          </span>
        </div>

        {/* Fusion Visualization - Clean Connection UI */}
        <div className="flex items-center justify-center gap-3 mb-8 relative z-10">
          
          {/* Socket 1: Filled */}
          <div className="w-[56px] h-[56px] rounded-full bg-white border border-slate-100 flex items-center justify-center shadow-[0_4px_15px_rgba(0,0,0,0.03)] relative z-10">
            <span className="font-bold text-slate-700 text-sm">乔</span>
            <div className="absolute -bottom-1.5 w-6 h-1 bg-indigo-200 rounded-full" />
          </div>
          
          <Plus className="w-4 h-4 text-slate-300 mx-1" />
          
          {/* Socket 2: Empty/Add */}
          <button className="w-[56px] h-[56px] rounded-full bg-slate-50/50 border border-dashed border-slate-300 flex items-center justify-center text-slate-400 hover:text-indigo-500 hover:border-indigo-300 hover:bg-indigo-50/30 transition-all shadow-sm group/add">
            <Plus className="w-5 h-5 group-hover/add:scale-110 transition-transform" />
          </button>

          <ArrowRight className="w-4 h-4 text-slate-300 mx-2" />

          {/* Result Agent - Soft Glowing Result */}
          <div className="relative">
            <div className="absolute inset-0 bg-indigo-200/40 blur-[16px] rounded-full animate-pulse" />
            <div className="w-[68px] h-[68px] rounded-[24px] bg-gradient-to-tr from-indigo-50 to-white border border-white flex items-center justify-center shadow-[0_8px_20px_rgba(99,102,241,0.12)] relative z-10 ring-4 ring-white/50 hover:scale-105 transition-transform duration-500">
              <div className="text-center flex flex-col items-center justify-center">
                <Sparkles className="w-[14px] h-[14px] text-indigo-400 mb-1" />
                <span className="font-bold text-indigo-900 text-[10px] tracking-wide">偏执天才</span>
              </div>
            </div>
          </div>
        </div>
        <p className="text-center text-[12px] text-slate-400 relative z-10">
          已加入 1 个思维锚点，继续添加以合成新视界
        </p>
      </ClearCard>

      <div className="flex flex-col items-center justify-center mb-6">
        <div className="w-[1px] h-5 bg-gradient-to-b from-slate-200 to-transparent" />
        <span className="text-[10px] text-slate-300 font-bold uppercase tracking-[0.2em] my-2">对谈方</span>
        <div className="w-[1px] h-5 bg-gradient-to-t from-slate-200 to-transparent" />
      </div>

      {/* Opponent Section - Seat B */}
      <ClearCard className="p-4 mb-8 flex items-center gap-4 border-dashed border-slate-200 hover:border-indigo-200 hover:bg-white/80 transition-all cursor-pointer group shadow-none hover:shadow-sm">
        <div className="w-11 h-11 rounded-full bg-slate-50 border border-slate-100 shadow-sm flex items-center justify-center text-slate-400 group-hover:text-indigo-400 transition-colors flex-shrink-0">
          <UserPlus className="w-5 h-5" />
        </div>
        <div className="flex-1">
          <h3 className="font-bold text-slate-700 text-[14px] mb-0.5">邀请对谈者 <span className="text-slate-400 font-normal text-xs">(Agent B)</span></h3>
          <p className="text-[12px] text-slate-500">选择另一个角色或人格群组</p>
        </div>
        <div className="bg-slate-100/80 text-slate-500 px-3.5 py-1.5 rounded-lg text-[12px] font-bold tracking-wide group-hover:bg-indigo-50 group-hover:text-indigo-600 transition-colors">
          邀请
        </div>
      </ClearCard>

      {/* Action / Question Area */}
      <div className="mb-4">
        <h3 className="font-bold text-slate-700 text-[14px] mb-3 flex items-center gap-2 pl-1">
          <MessageCircle className="w-[18px] h-[18px] text-teal-400" />
          抛出议题
        </h3>
        <div className="bg-white/60 backdrop-blur-xl rounded-[24px] p-4 border border-white shadow-[0_4px_20px_rgba(0,0,0,0.03)] mb-5">
          <textarea 
            placeholder="例如：在面临极度不确定的未来时，该如何做出决策？"
            className="w-full bg-transparent text-[14px] text-slate-700 placeholder:text-slate-400 outline-none resize-none h-20 custom-scrollbar leading-relaxed"
          />
        </div>
        
        <button className="w-full bg-slate-900 hover:bg-slate-800 text-white font-bold py-4 rounded-[20px] shadow-[0_8px_20px_rgba(15,23,42,0.15)] transition-all active:scale-[0.98] flex justify-center items-center gap-2">
          <span className="tracking-widest text-[14px]">开启跨时空会谈</span>
        </button>
      </div>
    </div>
  );
}

// --- TAB 3: 纪要 (Records) ---
function RecordsTab() {
  return (
    <div className="pt-14 animate-in fade-in slide-in-from-bottom-4 duration-700 ease-out">
      <div className="mb-8 pl-2">
        <h1 className="text-[28px] font-bold tracking-tight text-slate-800">灵感纪要</h1>
        <p className="text-slate-500 text-sm mt-2 font-medium">留存每一次思想的碰撞与回响</p>
      </div>

      <div className="space-y-4">
        {/* Record Item 1 */}
        <ClearCard className="p-5 relative overflow-hidden group hover:shadow-md transition-shadow cursor-pointer">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-indigo-400 rounded-l-2xl" />
          
          <div className="flex justify-between items-start mb-3 pl-2">
            <h3 className="font-bold text-slate-800 text-[15px] leading-snug pr-4 group-hover:text-indigo-600 transition-colors">
              关于“绝对权力下的孤独感”的探讨
            </h3>
            <span className="text-[10px] text-slate-400 font-bold tracking-wider uppercase flex items-center gap-1 shrink-0 bg-slate-50 px-2 py-1 rounded-md">
              <Clock className="w-[10px] h-[10px]" />
              2天前
            </span>
          </div>
          
          <div className="flex items-center gap-3 mb-4 pl-2">
            <div className="flex -space-x-1.5">
              <div className="w-[26px] h-[26px] rounded-full bg-rose-50 border-2 border-white flex items-center justify-center text-[10px] font-bold text-rose-500 shadow-sm z-20">秦</div>
              <div className="w-[26px] h-[26px] rounded-full bg-indigo-50 border-2 border-white flex items-center justify-center text-[10px] font-bold text-indigo-500 shadow-sm z-10">乔</div>
            </div>
            <span className="text-[12px] text-slate-500 font-medium">秦始皇 <span className="text-slate-300 mx-1">/</span> 乔布斯</span>
          </div>

          <div className="bg-slate-50/80 border border-slate-100/50 rounded-xl p-3.5">
            <p className="text-[12px] text-slate-500 leading-relaxed line-clamp-2">
              秦始皇认为权力需要绝对的集中来保证系统的运转，而乔布斯反驳道：没有对极简与纯粹的热爱，权力只会制造出平庸的废品...
            </p>
          </div>
        </ClearCard>

        {/* Record Item 2 */}
        <ClearCard className="p-5 relative overflow-hidden group hover:shadow-md transition-shadow cursor-pointer">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-teal-400 rounded-l-2xl" />
          
          <div className="flex justify-between items-start mb-3 pl-2">
            <h3 className="font-bold text-slate-800 text-[15px] leading-snug pr-4 group-hover:text-teal-600 transition-colors">
              如何面对旷野与轨道的选择？
            </h3>
            <span className="text-[10px] text-slate-400 font-bold tracking-wider uppercase flex items-center gap-1 shrink-0 bg-slate-50 px-2 py-1 rounded-md">
              <Clock className="w-[10px] h-[10px]" />
              1周前
            </span>
          </div>
          
          <div className="flex items-center gap-3 mb-4 pl-2">
            <div className="flex -space-x-1.5">
              <div className="w-[26px] h-[26px] rounded-full bg-white border-2 border-slate-100 flex items-center justify-center text-[10px] font-bold text-slate-500 shadow-sm z-20">我</div>
              <div className="w-[26px] h-[26px] rounded-[8px] bg-gradient-to-tr from-teal-50 to-emerald-50 border-2 border-white flex items-center justify-center shadow-sm z-10">
                <Sparkles className="w-3 h-3 text-teal-500" />
              </div>
            </div>
            <span className="text-[12px] text-slate-500 font-medium">普通人 <span className="text-slate-300 mx-1">/</span> 偏执天才(融合)</span>
          </div>

          <div className="bg-slate-50/80 border border-slate-100/50 rounded-xl p-3.5">
            <p className="text-[12px] text-slate-500 leading-relaxed line-clamp-2">
              融合意识指出：不要试图在第一份工作中寻找一生的意义，去打破既定的轨道，把它当作一个收集数据点的实验场...
            </p>
          </div>
        </ClearCard>
      </div>
    </div>
  );
}

// --- Shared Components ---
function ClearCard({ children, className = "" }: { children: React.ReactNode, className?: string }) {
  return (
    <div className={`bg-white/60 backdrop-blur-2xl border border-white rounded-[24px] shadow-[0_8px_30px_rgba(0,0,0,0.04)] ${className}`}>
      {children}
    </div>
  );
}
