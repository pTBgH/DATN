/**
 * Button Component
 * Versatile button with multiple variants and sizes
 */

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
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
    primary: 'bg-cyan-600 text-white hover:bg-cyan-700 disabled:bg-cyan-400',
    secondary: 'bg-slate-200 text-slate-900 hover:bg-slate-300 disabled:bg-slate-100',
    outline: 'border-2 border-cyan-600 text-cyan-600 hover:bg-cyan-50 disabled:border-cyan-300 disabled:text-cyan-300',
    ghost: 'text-cyan-600 hover:bg-cyan-50 disabled:text-cyan-300',
    danger: 'bg-red-600 text-white hover:bg-red-700 disabled:bg-red-400',
  };

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm font-medium rounded',
    md: 'px-4 py-2 text-base font-medium rounded-lg',
    lg: 'px-6 py-3 text-lg font-medium rounded-lg',
  };

  return (
    <button
      disabled={disabled || isLoading}
      className={`inline-flex items-center justify-center transition-colors duration-200 disabled:cursor-not-allowed ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      {...props}
    >
      {isLoading ? (
        <>
          <span className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"></span>
          Loading...
        </>
      ) : (
        children
      )}
    </button>
  );
}
