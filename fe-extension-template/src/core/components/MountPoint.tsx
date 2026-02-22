'use client';

import { Suspense, lazy, useMemo } from 'react';
import { useRegistry, useCoreServices } from '../providers/CoreProvider';
import { ExtensionErrorBoundary } from './ExtensionErrorBoundary';
import type { MountPointName } from '../types';

interface MountPointComponentProps {
  name: MountPointName;
  fallback?: React.ReactNode;
}

export function MountPoint({ name, fallback = null }: MountPointComponentProps) {
  const registry = useRegistry();
  const services = useCoreServices();
  const contributions = useMemo(() => registry.getMountPointContributions(name), [registry, name]);

  return (
    <>
      {contributions.map((contribution, index) => {
        const LazyComponent = lazy(contribution.component);
        return (
          <ExtensionErrorBoundary key={`${name}-${index}`} fallback={<div>Widget error</div>}>
            <Suspense fallback={fallback}>
              <LazyComponent services={services} />
            </Suspense>
          </ExtensionErrorBoundary>
        );
      })}
    </>
  );
}
