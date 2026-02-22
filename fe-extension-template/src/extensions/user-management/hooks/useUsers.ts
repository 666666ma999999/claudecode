'use client';

import { useEffect, useState } from 'react';
import { useCoreServices } from '@/core';
import type { UserRecord } from '../types/user';

export function useUsers() {
  const { api } = useCoreServices();
  const [users, setUsers] = useState<UserRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchUsers() {
      try {
        setLoading(true);
        const data = await api.get<UserRecord[]>('/users');
        if (!cancelled) {
          setUsers(data);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err : new Error('Failed to fetch users'));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    fetchUsers();
    return () => { cancelled = true; };
  }, [api]);

  return { users, loading, error };
}
