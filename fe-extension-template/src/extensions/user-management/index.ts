import type { ExtensionManifest } from '@/core';

const manifest: ExtensionManifest = {
  id: 'user-management',
  name: 'User Management',
  version: '1.0.0',
  description: 'User management extension',
  navigation: [
    { label: 'Users', path: '/users', icon: 'users', order: 10 },
  ],
  routes: [
    { path: '/users', component: () => import('./pages/UsersPage') },
  ],
  mountPoints: [
    { mountPoint: 'dashboard-widgets', component: () => import('./widgets/UserCountCard'), order: 10 },
  ],
};

export default manifest;
