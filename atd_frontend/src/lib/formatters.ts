/**
 * Utility functions for formatting data display
 * Handles text truncation, date formatting, salary display, and more
 */

/**
 * Truncate text to a maximum length and add ellipsis
 * @param text - Text to truncate
 * @param maxLength - Maximum length before truncation
 * @returns Truncated text with ellipsis if needed
 */
export function truncateText(text: string, maxLength: number): string {
  if (!text) return '';
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength) + '...';
}

/**
 * Format large numbers with K, M suffixes
 * @param num - Number to format
 * @returns Formatted number string
 */
export function formatNumber(num: number): string {
  if (num >= 1_000_000) {
    return (num / 1_000_000).toFixed(1) + 'M';
  }
  if (num >= 1_000) {
    return (num / 1_000).toFixed(1) + 'K';
  }
  return num.toString();
}

/**
 * Format salary range with currency
 * @param min - Minimum salary
 * @param max - Maximum salary
 * @param currency - Currency symbol (default: $)
 * @returns Formatted salary string
 */
export function formatSalary(
  min: number,
  max: number,
  currency: string = '$'
): string {
  const formatValue = (val: number) => {
    return currency + formatNumber(val);
  };
  return `${formatValue(min)} - ${formatValue(max)}`;
}

/**
 * Format date to readable string
 * @param date - Date string or Date object
 * @param format - Format type ('short', 'long', 'relative')
 * @returns Formatted date string
 */
export function formatDate(
  date: string | Date,
  format: 'short' | 'long' | 'relative' = 'short'
): string {
  const dateObj = typeof date === 'string' ? new Date(date) : date;

  if (format === 'relative') {
    const now = new Date();
    const diffMs = now.getTime() - dateObj.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffMins = Math.floor(diffMs / (1000 * 60));

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    if (diffDays < 30) return `${Math.floor(diffDays / 7)}w ago`;
    return `${Math.floor(diffDays / 30)}mo ago`;
  }

  if (format === 'long') {
    return dateObj.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  }

  return dateObj.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

/**
 * Format job location with city and country
 * @param city - City name
 * @param country - Country name
 * @returns Formatted location string
 */
export function formatLocation(city: string, country: string): string {
  if (city && country) {
    return `${city}, ${country}`;
  }
  return city || country || 'Remote';
}

/**
 * Format job type with proper styling
 * @param type - Job type (Full-time, Part-time, Contract, Freelance)
 * @returns Job type with badge color class
 */
export function getJobTypeBadgeClass(type: string): string {
  const typeMap: Record<string, string> = {
    'Full-time': 'bg-blue-100 text-blue-800',
    'Part-time': 'bg-amber-100 text-amber-800',
    'Contract': 'bg-purple-100 text-purple-800',
    'Freelance': 'bg-green-100 text-green-800',
  };
  return typeMap[type] || 'bg-slate-100 text-slate-800';
}

/**
 * Format application status with color
 * @param status - Application status
 * @returns Status with badge color class
 */
export function getStatusBadgeClass(status: string): string {
  const statusMap: Record<string, string> = {
    'Applied': 'bg-blue-100 text-blue-800',
    'Viewed': 'bg-cyan-100 text-cyan-800',
    'Shortlisted': 'bg-green-100 text-green-800',
    'Interview': 'bg-amber-100 text-amber-800',
    'Offered': 'bg-emerald-100 text-emerald-800',
    'Rejected': 'bg-red-100 text-red-800',
    'Withdrawn': 'bg-slate-100 text-slate-800',
  };
  return statusMap[status] || 'bg-slate-100 text-slate-800';
}

/**
 * Calculate days since application
 * @param applicationDate - Date of application
 * @returns Number of days
 */
export function daysSinceApplication(applicationDate: string | Date): number {
  const now = new Date();
  const appDate = typeof applicationDate === 'string' ? new Date(applicationDate) : applicationDate;
  const diffMs = now.getTime() - appDate.getTime();
  return Math.floor(diffMs / (1000 * 60 * 60 * 24));
}

/**
 * Check if text needs truncation
 * @param text - Text to check
 * @param maxLength - Maximum allowed length
 * @returns Boolean indicating if truncation is needed
 */
export function isTruncated(text: string, maxLength: number): boolean {
  return !!(text && text.length > maxLength);
}

/**
 * Format experience level
 * @param years - Years of experience
 * @returns Formatted experience level
 */
export function formatExperienceLevel(years: number): string {
  if (years < 1) return 'Fresher';
  if (years < 3) return 'Junior';
  if (years < 5) return 'Mid-level';
  if (years < 8) return 'Senior';
  return 'Lead';
}

/**
 * Create abbreviation from name
 * @param name - Full name
 * @returns Abbreviation (first letters of first and last name)
 */
export function getInitials(name: string): string {
  if (!name) return 'U';
  const parts = name.trim().split(' ');
  if (parts.length === 1) {
    return parts[0].substring(0, 2).toUpperCase();
  }
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
