import type { NotificationService } from '../types';

export function createNotificationService(): NotificationService {
  return {
    info(message: string): void {
      console.info(`[INFO] ${message}`);
    },
    warn(message: string): void {
      console.warn(`[WARN] ${message}`);
    },
    error(message: string): void {
      console.error(`[ERROR] ${message}`);
    },
    success(message: string): void {
      console.log(`[SUCCESS] ${message}`);
    },
  };
}
