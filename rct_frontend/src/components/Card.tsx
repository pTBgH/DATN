/**
 * Card Component — Minimalist Design
 * Soft shadows, 12px border-radius, optimal whitespace
 */

interface CardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
}

export function Card({
  children,
  className = '',
  hover = false,
}: CardProps) {
  const hoverClass = hover ? 'hover:shadow-md hover:scale-[1.01] transition-all duration-300 ease-in-out' : '';

  return (
    <div
      className={`rounded-[12px] bg-white shadow-sm border border-slate-100 p-6 ${hoverClass} ${className}`}
    >
      {children}
    </div>
  );
}

/**
 * Card Header Component
 * Title, description with optimal spacing
 */
interface CardHeaderProps {
  title: string;
  description?: string;
  children?: React.ReactNode;
}

export function CardHeader({
  title,
  description,
  children,
}: CardHeaderProps) {
  return (
    <div className="mb-6 flex items-start justify-between gap-4">
      <div className="flex-1">
        <h3 className="text-lg font-semibold text-slate-900">{title}</h3>
        {description && (
          <p className="mt-2 text-sm text-slate-500">{description}</p>
        )}
      </div>
      {children && <div className="flex-shrink-0">{children}</div>}
    </div>
  );
}

/**
 * Card Content Component
 * Body content with proper text color
 */
interface CardContentProps {
  children: React.ReactNode;
  className?: string;
}

export function CardContent({
  children,
  className = '',
}: CardContentProps) {
  return <div className={`text-slate-600 ${className}`}>{children}</div>;
}

/**
 * Card Footer Component
 * Footer actions with proper spacing
 */
interface CardFooterProps {
  children: React.ReactNode;
  className?: string;
}

export function CardFooter({
  children,
  className = '',
}: CardFooterProps) {
  return (
    <div
      className={`mt-6 flex items-center gap-3 border-t border-slate-100 pt-6 ${className}`}
    >
      {children}
    </div>
  );
}
