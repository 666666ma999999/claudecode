'use client';

import { useMemo } from 'react';
import { useRegistry } from '../providers/CoreProvider';

export function Navigation() {
  const registry = useRegistry();
  const items = useMemo(() => registry.getNavigationItems(), [registry]);

  return (
    <nav>
      <ul>
        <li><a href="/">Dashboard</a></li>
        {items.map(item => (
          <li key={item.path}>
            <a href={item.path}>
              {item.icon && <span>{item.icon}</span>}
              {item.label}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}
