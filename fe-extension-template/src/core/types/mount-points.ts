import type { CoreServices } from './services';

export interface MountPointProps {
  readonly services: CoreServices;
}

export const MOUNT_POINTS = {
  DASHBOARD_WIDGETS: 'dashboard-widgets',
  SIDEBAR_BOTTOM: 'sidebar-bottom',
  SETTINGS_PANELS: 'settings-panels',
  HEADER_ACTIONS: 'header-actions',
  USER_PROFILE_TABS: 'user-profile-tabs',
} as const;

export type MountPointName = (typeof MOUNT_POINTS)[keyof typeof MOUNT_POINTS];
