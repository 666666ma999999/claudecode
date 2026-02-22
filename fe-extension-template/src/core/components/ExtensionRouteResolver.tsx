'use client';

import { Suspense, lazy, useMemo } from 'react';
import { useRegistry } from '../providers/CoreProvider';
import { ExtensionErrorBoundary } from './ExtensionErrorBoundary';

interface Props {
  slug: string[];
}

export function ExtensionRouteResolver({ slug }: Props) {
  const registry = useRegistry();
  const path = '/' + slug.join('/');

  const matchedRoute = useMemo(() => {
    const routes = registry.getRoutes();
    return routes.find(r => path.startsWith(r.route.path));
  }, [registry, path]);

  if (!matchedRoute) {
    return <div>Page not found</div>;
  }

  const LazyPage = lazy(matchedRoute.route.component);

  return (
    <ExtensionErrorBoundary fallback={<div>Extension error</div>}>
      <Suspense fallback={<div>Loading...</div>}>
        <LazyPage />
      </Suspense>
    </ExtensionErrorBoundary>
  );
}
