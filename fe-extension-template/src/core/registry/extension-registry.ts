import type { ExtensionManifest, NavigationItem, MountPointContribution, ExtensionRoute } from '../types';

export class ExtensionRegistry {
  private extensions = new Map<string, ExtensionManifest>();

  register(manifest: ExtensionManifest): void {
    if (this.extensions.has(manifest.id)) {
      console.warn(`Extension "${manifest.id}" is already registered.`);
      return;
    }
    this.extensions.set(manifest.id, manifest);
  }

  get(id: string): ExtensionManifest | undefined {
    return this.extensions.get(id);
  }

  getAll(): ExtensionManifest[] {
    return Array.from(this.extensions.values());
  }

  getNavigationItems(): NavigationItem[] {
    return this.getAll()
      .flatMap(ext => ext.navigation ?? [])
      .sort((a, b) => (a.order ?? 100) - (b.order ?? 100));
  }

  getMountPointContributions(mountPoint: string): MountPointContribution[] {
    return this.getAll()
      .flatMap(ext => ext.mountPoints ?? [])
      .filter(mp => mp.mountPoint === mountPoint)
      .sort((a, b) => (a.order ?? 100) - (b.order ?? 100));
  }

  getRoutes(): Array<{ extensionId: string; route: ExtensionRoute }> {
    return this.getAll().flatMap(ext =>
      (ext.routes ?? []).map(route => ({ extensionId: ext.id, route }))
    );
  }
}
