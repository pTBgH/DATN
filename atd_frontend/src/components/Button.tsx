/**
 * Button Component — Minimalist Teal System
 * Variants: primary, secondary, outline + smooth transitions
 */

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  children: React.ReactNode;
}

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading = false,
  disabled = false,
  children,
  className = '',
  ...props
}: ButtonProps) {
  const variantClasses = {
    primary: 'bg-brand text-white hover:bg-brand-dark disabled:bg-brand/50',
    secondary: 'bg-slate-100 text-slate-900 hover:bg-slate-200 disabled:bg-slate-50',
    outline: 'border border-slate-200 text-slate-900 hover:bg-slate-50 disabled:border-slate-100 disabled:text-slate-400',
  };

  const sizeClasses = {
    sm: 'px-3 py-2 text-sm font-medium',
    md: 'px-4 py-2.5 text-base font-medium',
    lg: 'px-6 py-3 text-base font-medium',
  };

  return (
    <button
      disabled={disabled || isLoading}
      className={`inline-flex items-center justify-center rounded-[12px] transition-all duration-300 ease-in-out disabled:cursor-not-allowed active:scale-95 ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      {...props}
    >
      {isLoading ? (
        <>
          <span className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"></span>
          <span>Loading...</span>
        </>
      ) : (
        children
      )}
    </button>
  );
}
