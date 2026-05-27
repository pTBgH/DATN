'use client';

import { useState } from 'react';

/**
 * Expandable Component
 * Used for showing/hiding long text content with smooth transitions
 */

interface ExpandableProps {
  children: React.ReactNode;
  summary?: React.ReactNode;
  defaultOpen?: boolean;
  className?: string;
}

export function Expandable({
  children,
  summary,
  defaultOpen = false,
  className = '',
}: ExpandableProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  return (
    <details
      open={isOpen}
      onToggle={() => setIsOpen(!isOpen)}
      className={className}
    >
      <summary className="cursor-pointer select-none font-medium text-cyan-600 hover:text-cyan-700">
        {summary || (isOpen ? 'Show less' : 'Show more')}
      </summary>
      <div className="mt-3 text-slate-700">{children}</div>
    </details>
  );
}
