# Quick Start Guide - UI/UX Improvements

## For Developers: How to Use the New Components & Utilities

### 🚀 Quick Start in 5 Minutes

#### 1. Using Badges
```jsx
import { Badge } from '@/components/Badge';

// Simple badge
<Badge variant="primary">New</Badge>

// Status with color
<Badge variant="success">Active</Badge>

// Different sizes
<Badge size="sm">Small</Badge>
<Badge size="lg">Large</Badge>
```

#### 2. Using Cards
```jsx
import { Card, CardHeader, CardContent, CardFooter } from '@/components/Card';

<Card hover>
  <CardHeader title="Title" description="Subtitle" />
  <CardContent>Body content here</CardContent>
  <CardFooter>
    <button>Action</button>
  </CardFooter>
</Card>
```

#### 3. Using Buttons
```jsx
import { Button } from '@/components/Button';

<Button variant="primary">Submit</Button>
<Button variant="outline">Cancel</Button>
<Button isLoading={true}>Loading...</Button>
<Button disabled={true}>Disabled</Button>
```

#### 4. Using Expandable Sections
```jsx
import { Expandable } from '@/components/Expandable';

<Expandable summary="Click to expand">
  Long content that can be hidden...
</Expandable>
```

#### 5. Using Formatters
```jsx
import {
  truncateText,
  formatDate,
  formatSalary,
  getStatusBadgeClass
} from '@/lib/formatters';

// Truncate text
{truncateText("Long text...", 100)}

// Format dates
{formatDate(new Date(), 'relative')} // "5d ago"
{formatDate(new Date(), 'long')}     // "Tuesday, January 15, 2024"

// Format salary
{formatSalary(10000000, 20000000)} // "$10M - $20M"

// Get status color
<Badge className={getStatusBadgeClass('Offered')}>
  {getStatusBadgeClass('Offered')}
</Badge>
```

---

## 📚 Component API Reference

### Badge
```jsx
<Badge
  variant="primary"      // default | success | warning | error | info | primary
  size="md"              // sm | md | lg
  className="custom"     // optional additional classes
>
  Content
</Badge>
```

### Card
```jsx
<Card
  hover={true}           // optional: add hover effects
  noBorder={false}       // optional: hide border
  className="custom"     // optional additional classes
>
  {children}
</Card>

// CardHeader
<CardHeader
  title="Title"          // required
  description="Desc"     // optional
  children={<button />}  // optional: right-side content
/>

// CardContent
<CardContent className="custom">
  {children}
</CardContent>

// CardFooter
<CardFooter className="custom">
  {children}
</CardFooter>
```

### Button
```jsx
<Button
  variant="primary"      // primary | secondary | outline | ghost | danger
  size="md"              // sm | md | lg
  isLoading={false}      // optional: show loading spinner
  disabled={false}       // optional: disable button
  onClick={() => {}}     // optional: click handler
  className="custom"     // optional additional classes
  type="button"          // optional: button | submit | reset
>
  Button Text
</Button>
```

### Expandable
```jsx
<Expandable
  summary="Click here"   // optional: custom text
  defaultOpen={false}    // optional: start expanded
  className="custom"     // optional additional classes
>
  {children}
</Expandable>
```

---

## 🎨 Formatter Functions

### Text Formatting
```jsx
// Truncate text to max length
truncateText(text, 150)
// Example: "This is a long text..." → "This is a long text..."

// Check if text needs truncation
isTruncated(text, 150)
// Example: true | false
```

### Number Formatting
```jsx
// Format large numbers
formatNumber(1000000)
// Example: 1000000 → "1M"

// Format salary range
formatSalary(10000000, 20000000)
// Example: "10M - 20M"

// Format candidate count
formatCandidateCount(45)
// Example: "45 candidates"
```

### Date Formatting
```jsx
// Format date with different styles
formatDate("2024-01-15", "short")     // "Jan 15, 2024"
formatDate("2024-01-15", "long")      // "Monday, January 15, 2024"
formatDate("2024-01-15", "relative")  // "5d ago"

// Calculate days since application
daysSinceApplication("2024-01-10")
// Example: 5
```

### Status Functions
```jsx
// Get badge color class for application status
getStatusBadgeClass("Offered")
// Returns: "bg-emerald-100 text-emerald-800"

// Get badge color class for job status (RCT only)
getJobStatusBadgeClass("Open")
// Returns: "bg-green-100 text-green-800"

// Get job type badge color
getJobTypeBadgeClass("Full-time")
// Returns: "bg-blue-100 text-blue-800"
```

### Utility Functions
```jsx
// Get name initials
getInitials("John Doe")
// Example: "JD"

// Format experience level
formatExperienceLevel(5)
// Example: "Mid-level"

// Format location
formatLocation("Ho Chi Minh", "Vietnam")
// Example: "Ho Chi Minh, Vietnam"
```

---

## 📝 Common Patterns

### Pattern 1: Job Card
```jsx
import { Card } from '@/components/Card';
import { Badge } from '@/components/Badge';
import { truncateText, getStatusBadgeClass } from '@/lib/formatters';

<Card hover>
  <div className="space-y-3">
    <div className="flex justify-between">
      <h3 className="font-semibold">{job.title}</h3>
      <Badge className={getStatusBadgeClass(status)}>
        {status}
      </Badge>
    </div>
    
    <p className="text-sm text-slate-600">
      {truncateText(job.description, 150)}
    </p>
    
    <div className="flex gap-2">
      <Badge variant="info">45 applies</Badge>
      <Badge variant="default">2k views</Badge>
    </div>
  </div>
</Card>
```

### Pattern 2: Status Display
```jsx
import { Badge } from '@/components/Badge';
import { getStatusBadgeClass } from '@/lib/formatters';

// Simple status
<Badge variant="success">Active</Badge>

// Dynamic status color
<Badge className={getStatusBadgeClass(status)}>
  {status}
</Badge>

// Status with meta info
<div className="flex gap-2">
  <Badge>{status}</Badge>
  <span className="text-sm text-slate-600">
    {formatDate(date, 'relative')}
  </span>
</div>
```

### Pattern 3: Long Content with Expandable
```jsx
import { Expandable } from '@/components/Expandable';

{description.length > 500 ? (
  <Expandable summary="Read more">
    {description}
  </Expandable>
) : (
  <p>{description}</p>
)}
```

### Pattern 4: Form with Filters
```jsx
import { Button } from '@/components/Button';

<form className="flex gap-3">
  <input
    name="q"
    placeholder="Search..."
    className="flex-1 rounded-lg border px-4 py-2"
  />
  
  <select
    name="status"
    className="rounded-lg border px-4 py-2"
  >
    <option>All statuses</option>
    <option>Active</option>
    <option>Inactive</option>
  </select>
  
  <Button variant="primary" type="submit">
    Filter
  </Button>
</form>
```

---

## 🎯 Best Practices

### Do ✅
```jsx
// Use formatters for consistent display
{formatDate(date, 'relative')}

// Use Badge for statuses
<Badge className={getStatusBadgeClass(status)}>
  {status}
</Badge>

// Use Card for grouped content
<Card hover>...</Card>

// Use Expandable for long content
{content.length > 500 && <Expandable>...</Expandable>}

// Use line-clamp classes
<p className="line-clamp-2">{text}</p>

// Use truncateText for display
{truncateText(text, 150)}
```

### Don't ❌
```jsx
// Don't hardcode colors
<span style={{ color: '#0891b2' }}>Bad</span>

// Don't use inline styles
<span style={{ padding: '10px' }}>Bad</span>

// Don't truncate with JS slice()
{text.slice(0, 150)}

// Don't create custom badges
<span className="px-2 py-1 rounded">Bad</span>

// Don't repeat formatting logic
const formatted = new Date().toLocaleDateString()
// Instead: formatDate(date, 'short')

// Don't use arbitrary Tailwind values
<div className="p-[10px]">Bad</div>
// Instead: <div className="p-2.5">Good</div>
```

---

## 🚀 Adding to a New Page

### Step 1: Import Components
```jsx
import { Card, CardHeader, CardContent } from '@/components/Card';
import { Badge } from '@/components/Badge';
import { Button } from '@/components/Button';
import { Expandable } from '@/components/Expandable';
```

### Step 2: Import Formatters
```jsx
import {
  truncateText,
  formatDate,
  formatSalary,
  getStatusBadgeClass,
  formatNumber,
} from '@/lib/formatters';
```

### Step 3: Use in Template
```jsx
<div className="space-y-6">
  <h1 className="text-3xl font-bold">Page Title</h1>
  
  <Card hover>
    <CardHeader title="Item" />
    <CardContent>
      {truncateText(description, 150)}
    </CardContent>
  </Card>
  
  <Badge className={getStatusBadgeClass(status)}>
    {status}
  </Badge>
  
  <Button variant="primary">Action</Button>
</div>
```

---

## 🔍 Common Issues & Solutions

### Issue: Badge color not showing
**Solution:** Use `className` prop with formatter function
```jsx
// Wrong ❌
<Badge variant={status}>

// Right ✅
<Badge className={getStatusBadgeClass(status)}>
```

### Issue: Text truncation not working
**Solution:** Use `line-clamp-*` class instead of truncateText
```jsx
// For display truncation:
<p className="line-clamp-2">{text}</p>

// truncateText() is for dynamic strings in formatters
{truncateText(text, 150)}
```

### Issue: Expandable not showing content
**Solution:** Check content length, make sure > 500 chars or use defaultOpen
```jsx
<Expandable defaultOpen={true}>
  {content}
</Expandable>
```

### Issue: Button loading spinner not showing
**Solution:** Ensure `isLoading` prop is boolean
```jsx
<Button isLoading={isLoading}>
  {isLoading ? 'Loading...' : 'Submit'}
</Button>
```

---

## 📖 Full Documentation

For detailed information about each component and formatter, see:
- **ATD Frontend:** `atd_frontend/IMPROVEMENTS.md`
- **RCT Frontend:** `rct_frontend/IMPROVEMENTS.md`
- **Summary:** `IMPROVEMENTS_SUMMARY.md`

---

## 💡 Examples by Use Case

### Display a Job
```jsx
<Card hover>
  <h3 className="font-semibold">{job.title}</h3>
  <p className="text-sm text-slate-600">{job.company}</p>
  <p className="text-sm">{truncateText(job.description, 100)}</p>
  <div className="mt-3 flex gap-2">
    <Badge variant="primary">{formatSalary(job.min, job.max)}</Badge>
    <Badge>{formatDate(job.deadline, 'relative')}</Badge>
  </div>
</Card>
```

### Show Application Status
```jsx
<Badge className={getStatusBadgeClass(app.status)}>
  {getStatusIcon(app.status)} {getStatusLabel(app.status)}
</Badge>
```

### Handle Long Description
```jsx
{description.length > 500 ? (
  <Expandable summary="View full description">
    {description}
  </Expandable>
) : (
  <p>{description}</p>
)}
```

### Create an Action Button
```jsx
<Button
  variant="primary"
  onClick={handleApply}
  isLoading={isSubmitting}
>
  Apply Now →
</Button>
```

---

## 🆘 Need Help?

1. **Check the component file:** Look at the JSDoc comments in `src/components/`
2. **Check the formatter file:** Look at examples in `src/lib/formatters.ts`
3. **Check the pages:** See how existing pages use components
4. **Read IMPROVEMENTS.md:** Full documentation in each frontend

---

**Happy coding! 🎉**
