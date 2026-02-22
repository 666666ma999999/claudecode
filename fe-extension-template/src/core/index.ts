// Types
export type { ExtensionManifest, NavigationItem, ExtensionRoute, MountPointContribution } from './types';
export type { CoreServices, AuthService, ApiClient, EventBus, ThemeService, NotificationService, RouterService, User } from './types';
export type { CoreEvents } from './types';
export type { MountPointProps, MountPointName } from './types';
export { MOUNT_POINTS } from './types';

// Hooks
export { useCoreServices, useRegistry } from './providers/CoreProvider';

// Components (for app layout)
export { CoreProvider } from './providers/CoreProvider';
export { MountPoint } from './components/MountPoint';
export { ExtensionRouteResolver } from './components/ExtensionRouteResolver';
export { Navigation } from './components/Navigation';
export { ExtensionErrorBoundary } from './components/ExtensionErrorBoundary';
