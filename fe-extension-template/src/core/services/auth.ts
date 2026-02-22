import type { AuthService, User } from '../types';

export function createAuthService(): AuthService {
  let currentUser: User | null = null;
  const changeCallbacks = new Set<(user: User | null) => void>();

  return {
    getCurrentUser(): User | null {
      return currentUser;
    },

    isAuthenticated(): boolean {
      return currentUser !== null;
    },

    getToken(): string | null {
      if (typeof window === 'undefined') return null;
      return localStorage.getItem('auth_token');
    },

    onAuthChange(callback: (user: User | null) => void): () => void {
      changeCallbacks.add(callback);
      return () => {
        changeCallbacks.delete(callback);
      };
    },
  };
}
