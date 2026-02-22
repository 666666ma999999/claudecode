import type { ThemeService } from '../types';

type Theme = 'light' | 'dark';

const STORAGE_KEY = 'app-theme';

export function createThemeService(): ThemeService {
  const changeCallbacks = new Set<(theme: Theme) => void>();

  function getSystemTheme(): Theme {
    if (typeof window === 'undefined') return 'light';
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  return {
    getTheme(): Theme {
      if (typeof window === 'undefined') return 'light';
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored === 'light' || stored === 'dark') return stored;
      return getSystemTheme();
    },

    setTheme(theme: Theme): void {
      if (typeof window === 'undefined') return;
      localStorage.setItem(STORAGE_KEY, theme);
      changeCallbacks.forEach(cb => cb(theme));
    },

    onThemeChange(callback: (theme: Theme) => void): () => void {
      changeCallbacks.add(callback);
      return () => {
        changeCallbacks.delete(callback);
      };
    },
  };
}
