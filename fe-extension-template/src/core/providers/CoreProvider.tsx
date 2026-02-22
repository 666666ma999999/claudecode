'use client';

import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import type { CoreServices } from '../types';
import { ExtensionRegistry } from '../registry/extension-registry';
import { loadExtensions } from '../registry/load-extensions';
import { createCoreServices } from '../services';

const CoreServicesContext = createContext<CoreServices | null>(null);
const RegistryContext = createContext<ExtensionRegistry | null>(null);

export function CoreProvider({ children }: { children: ReactNode }) {
  const [services] = useState<CoreServices>(() => createCoreServices());
  const [registry] = useState<ExtensionRegistry>(() => {
    const reg = new ExtensionRegistry();
    for (const manifest of loadExtensions()) {
      reg.register(manifest);
    }
    return reg;
  });

  useEffect(() => {
    const cleanups: Array<() => void> = [];
    for (const manifest of registry.getAll()) {
      if (manifest.lifecycle?.onInit) {
        manifest.lifecycle.onInit(services);
      }
      if (manifest.lifecycle?.onDestroy) {
        cleanups.push(manifest.lifecycle.onDestroy);
      }
    }
    return () => {
      cleanups.forEach(fn => fn());
    };
  }, [registry, services]);

  return (
    <CoreServicesContext.Provider value={services}>
      <RegistryContext.Provider value={registry}>
        {children}
      </RegistryContext.Provider>
    </CoreServicesContext.Provider>
  );
}

export function useCoreServices(): CoreServices {
  const ctx = useContext(CoreServicesContext);
  if (!ctx) throw new Error('useCoreServices must be used within CoreProvider');
  return ctx;
}

export function useRegistry(): ExtensionRegistry {
  const ctx = useContext(RegistryContext);
  if (!ctx) throw new Error('useRegistry must be used within CoreProvider');
  return ctx;
}
