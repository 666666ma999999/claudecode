// Core-defined events. Extensions cannot add new event types.
export interface CoreEvents {
  'user:updated': { userId: string };
  'user:deleted': { userId: string };
  'notification:created': { message: string; level: 'info' | 'warn' | 'error' };
  'theme:changed': { theme: 'light' | 'dark' };
}
