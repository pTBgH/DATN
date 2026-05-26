/**
 * Card Component
 * Flexible container for displaying content with consistent styling
 */

interface CardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
  noBorder?: boolean;
}

export function Card({
  children,
  className = '',
  hover = false,
  noBorder = false,
}: CardProps) {
  const borderClass = noBorder ? '' : 'border border-slate-200';
  const hoverClass = hover ? 'hover:shadow-md hover:border-slate-300 transition-all duration-200' : '';

  return (
    <div
      className={`rounded-lg bg-white p-5 ${borderClass} ${hoverClass} ${className}`}
    >
      {children}
    </div>
  );
}

/**
 * Card Header Component
 * Used for card titles and descriptions
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
    <div className="mb-4 flex items-center justify-between">
      <div className="flex-1">
        <h3 className="text-lg font-semibold text-slate-900">{title}</h3>
        {description && (
          <p className="mt-1 text-sm text-slate-600">{description}</p>
        )}
      </div>
      {children && <div>{children}</div>}
    </div>
  );
}

/**
 * Card Content Component
 * Used for card body content
 */
interface CardContentProps {
  children: React.ReactNode;
  className?: string;
}

export function CardContent({
  children,
  className = '',
}: CardContentProps) {
  return <div className={`text-slate-700 ${className}`}>{children}</div>;
}

/**
 * Card Footer Component
 * Used for card footer actions
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
      className={`mt-4 flex items-center gap-2 border-t border-slate-200 pt-4 ${className}`}
    >
      {children}
    </div>
  );
}
