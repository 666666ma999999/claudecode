'use client';

import type { ReactNode } from 'react';

interface CardProps {
  title?: string;
  children: ReactNode;
  className?: string;
}

export function Card({ title, children, className }: CardProps) {
  return (
    <div className={className} style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: '8px' }}>
      {title && <h3>{title}</h3>}
      {children}
    </div>
  );
}
