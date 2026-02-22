import type { CoreEvents } from './events';

export interface User {
  readonly id: string;
  readonly name: string;
  readonly email: string;
  readonly roles: readonly string[];
}

export interface RequestOptions {
  readonly params?: Record<string, string>;
  readonly headers?: Record<string, string>;
}

export interface AuthService {
  readonly getCurrentUser: () => User | null;
  readonly isAuthenticated: () => boolean;
  readonly getToken: () => string | null;
  readonly onAuthChange: (callback: (user: User | null) => void) => () => void;
}

export interface ApiClient {
  readonly get: <T>(path: string, options?: RequestOptions) => Promise<T>;
  readonly post: <T>(path: string, data?: unknown, options?: RequestOptions) => Promise<T>;
  readonly put: <T>(path: string, data?: unknown, options?: RequestOptions) => Promise<T>;
  readonly delete: <T>(path: string, options?: RequestOptions) => Promise<T>;
}

export interface EventBus {
  readonly emit: <K extends keyof CoreEvents>(event: K, data: CoreEvents[K]) => void;
  readonly on: <K extends keyof CoreEvents>(event: K, handler: (data: CoreEvents[K]) => void) => () => void;
  readonly off: <K extends keyof CoreEvents>(event: K, handler: (data: CoreEvents[K]) => void) => void;
}

export interface ThemeService {
  readonly getTheme: () => 'light' | 'dark';
  readonly setTheme: (theme: 'light' | 'dark') => void;
  readonly onThemeChange: (callback: (theme: 'light' | 'dark') => void) => () => void;
}

export interface NotificationService {
  readonly info: (message: string) => void;
  readonly warn: (message: string) => void;
  readonly error: (message: string) => void;
  readonly success: (message: string) => void;
}

export interface RouterService {
  readonly navigate: (path: string) => void;
  readonly getCurrentPath: () => string;
}

export interface CoreServices {
  readonly auth: AuthService;
  readonly api: ApiClient;
  readonly events: EventBus;
  readonly theme: ThemeService;
  readonly notifications: NotificationService;
  readonly router: RouterService;
}
