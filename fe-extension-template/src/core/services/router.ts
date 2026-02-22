import type { RouterService } from '../types';

export function createRouterService(): RouterService {
  return {
    navigate(path: string): void {
      if (typeof window !== 'undefined') {
        window.history.pushState({}, '', path);
        window.dispatchEvent(new PopStateEvent('popstate'));
      }
    },

    getCurrentPath(): string {
      if (typeof window === 'undefined') return '/';
      return window.location.pathname;
    },
  };
}
