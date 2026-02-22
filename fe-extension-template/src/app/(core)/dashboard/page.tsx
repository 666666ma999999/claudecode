import { MountPoint } from '@/core';

export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <MountPoint name="dashboard-widgets" />
      </div>
    </div>
  );
}
