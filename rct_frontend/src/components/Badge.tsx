/**
 * Badge Component — Minimalist Indigo System
 * Primary (indigo light) + muted variants
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
    primary: 'bg-brand-light text-brand-dark font-medium',
    muted: 'bg-slate-100 text-slate-600 font-medium',
  };

  const sizeClasses = {
    sm: 'px-2.5 py-1 text-xs',
    md: 'px-3 py-1.5 text-sm',
    lg: 'px-4 py-2 text-base',
  };

  return (
    <span
      className={`inline-flex items-center rounded-[12px] whitespace-nowrap transition-colors duration-300 ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
    >
      {children}
    </span>
  );
}
