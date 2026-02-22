import type { ComponentType } from 'react';
import type { CoreServices } from './services';
import type { MountPointProps } from './mount-points';

export interface NavigationItem {
  readonly label: string;
  readonly path: string;
  readonly icon?: string;
  readonly order?: number;
}

export interface ExtensionRoute {
  readonly path: string;
  readonly component: () => Promise<{ default: ComponentType }>;
}

export interface MountPointContribution {
  readonly mountPoint: string;
  readonly component: () => Promise<{ default: ComponentType<MountPointProps> }>;
  readonly order?: number;
}

export interface ExtensionManifest {
  readonly id: string;
  readonly name: string;
  readonly version: string;
  readonly description: string;
  readonly navigation?: NavigationItem[];
  readonly routes?: ExtensionRoute[];
  readonly mountPoints?: MountPointContribution[];
  readonly lifecycle?: {
    onInit?: (services: CoreServices) => void | Promise<void>;
    onDestroy?: () => void | Promise<void>;
  };
}
