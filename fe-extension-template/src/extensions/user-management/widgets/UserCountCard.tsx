'use client';

import { useEffect, useState } from 'react';
import type { MountPointProps } from '@/core';

export default function UserCountCard({ services }: MountPointProps) {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchCount() {
      try {
        const users = await services.api.get<{ length: number }>('/users');
        if (!cancelled && Array.isArray(users)) {
          setCount((users as unknown[]).length);
        }
      } catch {
        if (!cancelled) setCount(0);
      }
    }

    fetchCount();
    return () => { cancelled = true; };
  }, [services.api]);

  return (
    <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: '8px' }}>
      <h3>Total Users</h3>
      <p style={{ fontSize: '2rem', fontWeight: 'bold' }}>
        {count === null ? '...' : count}
      </p>
    </div>
  );
}
