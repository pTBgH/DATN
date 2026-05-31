/**
 * Badge Component — Teal brand system
 * Primary (teal) + muted variants only
 */

interface BadgeProps {
  children: React.ReactNode;
  variant?: 'primary' | 'muted';
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export function Badge({
  children,
  variant = 'primary',
  size = 'md',
  className = '',
}: BadgeProps) {
  const variantClasses = {
    primary: 'bg-brand-light text-brand-dark',
    muted: 'bg-slate-100 text-slate-600',
  };

  const sizeClasses = {
    sm: 'px-2 py-1 text-xs',
    md: 'px-3 py-1.5 text-sm',
    lg: 'px-4 py-2 text-base',
  };

  return (
    <span
      className={`inline-flex items-center rounded-full font-medium ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
    >
      {children}
    </span>
  );
}
