
export enum AppView {
  DASHBOARD = 'dashboard',
  PRACTICE = 'practice',
  SIMULATE = 'simulate',
  COMMUNITY = 'community',
  LEARN = 'learn',
  SETTINGS = 'settings',
  RESUME = 'resume'
}

export type UserTier = 'free' | 'pro';

export interface UserStats {
  streak: number;
  xp: number;
  level: number;
  tier: UserTier;
  simulationsLeft: number;
}

export interface SkillScore {
  name: string;
  value: number;
  fullMark: number;
}

export interface ActivityDay {
  date: string;
  count: number;
}

export interface Question {
  id: string;
  category: string;
  difficulty: number;
  text: string;
  modelAnswer?: string;
}

export interface SimulationSession {
  type: string;
  role: string;
  duration: number;
  status: 'idle' | 'active' | 'review';
}
