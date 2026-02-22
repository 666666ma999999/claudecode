'use client';

import { useUsers } from '../hooks/useUsers';
import { UserTable } from '../components/UserTable';

export default function UsersPage() {
  const { users, loading, error } = useUsers();

  if (loading) return <div>Loading users...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      <h1>Users</h1>
      <UserTable users={users} />
    </div>
  );
}
