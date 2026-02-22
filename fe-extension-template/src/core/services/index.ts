import type { CoreServices } from '../types';
import { createEventBus } from './event-bus';
import { createAuthService } from './auth';
import { createApiClient } from './api-client';
import { createThemeService } from './theme';
import { createNotificationService } from './notifications';
import { createRouterService } from './router';

export function createCoreServices(): CoreServices {
  const auth = createAuthService();
  const api = createApiClient(auth);
  const events = createEventBus();
  const theme = createThemeService();
  const notifications = createNotificationService();
  const router = createRouterService();

  return { auth, api, events, theme, notifications, router };
}
