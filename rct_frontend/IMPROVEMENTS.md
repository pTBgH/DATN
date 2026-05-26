# RCT Frontend (Nhà Tuyển Dụng) - UI/UX Improvements Documentation

## Tổng Quan Cải Thiện

Tài liệu này ghi lại toàn bộ những cải thiện UI/UX được thực hiện trên RCT Frontend (phần mềm dành cho nhà tuyển dụng) để nâng cao hiệu quả quản lý công việc, hiển thị dữ liệu rõ ràng, và xử lý các trường hợp dữ liệu lớn.

**Ngày cập nhật:** 2024
**Phiên bản:** 1.0

---

## 1. Utility Functions (`src/lib/formatters.ts`)

### Mục đích
Tập hợp các hàm hỗ trợ định dạng dữ liệu để hiển thị nhất quán trên toàn ứng dụng.

### Các Hàm Chính

#### `formatSalary(min, max, currency)`
- **Mục đích:** Định dạng khoảng lương với đơn vị tiền tệ
- **Ví dụ:**
  ```typescript
  formatSalary(10000000, 20000000, '$') // "$10M - $20M"
  ```

#### `truncateText(text, maxLength)`
- **Mục đích:** Cắt ngắn văn bản dài khi hiển thị trong danh sách
- **Sử dụng:** Tiêu đề công việc, mô tả lại công việc
- **Ví dụ:**
  ```typescript
  truncateText("Mô tả rất dài...", 150)
  ```

#### `formatDate(date, format)`
- **Mục đích:** Định dạng ngày tháng theo kiểu khác nhau
- **Format types:**
  - `short`: "Jan 15, 2024"
  - `long`: "Tuesday, January 15, 2024"
  - `relative`: "5d ago", "1h ago"

#### `getJobStatusBadgeClass(status)`
- **Mục đích:** Trả về CSS classes cho status badge của công việc
- **Hỗ trợ trạng thái:** Open, Closed, Draft, Paused, Pending, Approved, Rejected
- **Color mapping:**
  ```
  Open → green (đang tuyển)
  Closed → red (đã đóng)
  Draft → slate (nháp)
  Paused → amber (tạm dừng)
  Pending → blue (chờ duyệt)
  Approved → emerald (được duyệt)
  Rejected → red (bị từ chối)
  ```

#### `formatCandidateCount(count)`
- **Mục đích:** Định dạng số lượng ứng viên
- **Ví dụ:**
  ```typescript
  formatCandidateCount(0) // "No candidates"
  formatCandidateCount(1) // "1 candidate"
  formatCandidateCount(5) // "5 candidates"
  ```

#### `getJobTypeBadgeClass(type)`
- **Mục đích:** Trả về CSS classes cho job type
- **Hỗ trợ:** Full-time, Part-time, Contract, Freelance

#### `formatExperienceLevel(years)`
- **Mục đích:** Chuyển đổi số năm kinh nghiệm thành level text
- **Mapping:**
  ```
  < 1 năm → Fresher
  1-3 năm → Junior
  3-5 năm → Mid-level
  5-8 năm → Senior
  > 8 năm → Lead
  ```

---

## 2. Reusable Components

### Badge Component (`src/components/Badge.tsx`)
**Mục đích:** Hiển thị job status, candidate counts, filters với màu sắc khác nhau

**Variants:**
- `default` - Xám
- `success` - Xanh lá (mở, được duyệt)
- `warning` - Vàng cam (chờ duyệt, tạm dừng)
- `error` - Đỏ (từ chối, đã đóng)
- `info` - Xanh dương (thông tin chung)
- `primary` - Cyan (thương hiệu, hành động)

**Sizes:** `sm` | `md` | `lg`

**Ví dụ sử dụng:**
```jsx
<Badge variant="success">✓ Đang tuyển</Badge>
<Badge variant="primary" size="lg">💼 45 ứng tuyển</Badge>
<Badge variant="warning">⏳ Chờ duyệt</Badge>
```

### Card Components (`src/components/Card.tsx`)
**Bao gồm:**
- `Card` - Container chính
- `CardHeader` - Tiêu đề + mô tả + actions
- `CardContent` - Nội dung chính
- `CardFooter` - Phần hành động ở cuối

**Props chính:**
- `hover` - Thêm hiệu ứng hover (shadow + border color change)
- `noBorder` - Ẩn đường viền
- `className` - CSS tùy chỉnh

**Ví dụ:**
```jsx
<Card hover>
  <CardHeader title="Senior Developer" />
  <CardContent>
    <p>45 candidates applied</p>
  </CardContent>
  <CardFooter>
    <Button>Manage</Button>
  </CardFooter>
</Card>
```

### Button Component (`src/components/Button.tsx`)
**Variants:**
- `primary` - Hành động chính
- `secondary` - Hành động thứ cấp
- `outline` - Hành động phụ
- `ghost` - Hành động nhẹ
- `danger` - Hành động nguy hiểm (xóa, từ chối)

**Sizes:** `sm` | `md` | `lg`

**Props:**
- `isLoading` - Hiển thị loading spinner
- `disabled` - Vô hiệu hóa button

**Ví dụ:**
```jsx
<Button variant="primary">Tạo công việc</Button>
<Button variant="danger">Xóa</Button>
<Button variant="outline" size="sm">Chi tiết</Button>
```

### Expandable Component (`src/components/Expandable.tsx`)
**Mục đích:** Hiển thị/ẩn nội dung dài một cách mượt mà
**Hữu ích cho:** Mô tả công việc, yêu cầu ứng viên khi quá dài

---

## 3. Page Improvements

### 3.1 Workspace Jobs List Page (`src/app/recruiter/[wsId]/jobs/page.tsx`)

#### Cải Thiện:

1. **Page Header**
   - Tiêu đề rõ ràng: "Danh Sách Công Việc"
   - Mô tả trang: "Quản lý và theo dõi các vị trí tuyển dụng"

2. **Filter & Search Form**
   - Input tìm kiếm theo tiêu đề
   - Select dropdown cho trạng thái với emoji icons
   - Button "Lọc" dùng Button component
   - Responsive: flex-wrap trên mobile
   - Modern style: rounded-lg, focus states

3. **Result Counter**
   - Hiển thị trong gradient background box
   - Tổng số công việc + phân trang
   - Màu cyan để highlight

4. **Job Cards**
   - Dùng Card component với hover effects
   - Layout:
     - Tiêu đề công việc (font-semibold)
     - Deadline
     - Status badge (color-coded)
     - Meta badges: 👁️ views + 💼 applies
     - "Chi tiết →" button

5. **Empty State**
   - Emoji icon 📋
   - Tin nhắn thân thiện
   - Gợi ý hành động

#### Status Colors
```
Draft → 📝 (slate - background)
Pending → ⏳ (blue - waiting)
Published → ✓ (green - active)
Closed → 🚫 (red - inactive)
Rejected → ❌ (red - error)
```

#### Code Example
```jsx
<Badge className={getJobStatusBadgeClass(j.status)}>
  {getStatusIcon(j.status)} {j.status}
</Badge>
```

---

## 4. Design System

### Color Palette
```css
Primary: cyan-600 (#0891b2) - Thương hiệu chính
Success: green-600 (#16a34a) - Thành công, Mở
Warning: amber-600 (#b45309) - Cảnh báo, Chờ duyệt
Error: red-600 (#dc2626) - Lỗi, Từ chối
Info: blue-600 (#2563eb) - Thông tin
Neutral: slate-* - Backgrounds, Text
Emerald: emerald-600 - Đã duyệt
```

### Typography Hierarchy
```
Page Title: text-3xl font-bold
Section Title: text-lg font-semibold
Card Title: text-lg font-semibold
Body: text-base text-slate-700
Small: text-sm text-slate-600
Label: text-xs uppercase tracking-wide
```

### Spacing System
```
Gaps: gap-2, gap-3, gap-4, gap-6
Padding: p-4, p-5, px-4 py-2, px-3 py-1.5
Margins: mt-2, mb-4, space-y-3
Border radius: rounded-lg (8px)
```

---

## 5. Xử Lý Dữ Liệu Lớn

### Chiến Lược cho Recruiter

| Trường dữ liệu | Chiến lược | Max chiều dài |
|---|---|---|
| Job title | line-clamp-1 | 80 ký tự |
| Candidate count | Badge | Dynamic |
| Job status | Status badge | 20 ký tự |
| Deadline | Formatted date | Fixed |
| View/Apply count | Badge | Dynamic |
| Job description (detail) | Expandable nếu > 500 | Unlimited |

### Examples

**Number Formatting:**
```typescript
// Views/Applies display
👁️ {formatNumber(j.view_count)} lượt xem
💼 {j.apply_count} ứng tuyển
```

**Candidate Count:**
```jsx
<Badge variant="info" size="sm">
  {formatCandidateCount(j.apply_count)}
</Badge>
```

---

## 6. Responsive Design

### Breakpoints
- **Mobile (default):** < 640px - single column
- **Tablet (sm):** ≥ 640px - stacked layout
- **Desktop (md):** ≥ 768px - full layout
- **Large (lg):** ≥ 1024px - optimized spacing

### Responsive Examples
```jsx
// Job cards adjust layout
<div className="flex items-start justify-between gap-4">
  {/* Left: title + info */}
  {/* Right: status + button */}
</div>

// Form inputs stack on mobile
<form className="flex flex-wrap gap-3">
  <input className="flex-1" />
  <select className="rounded-lg" />
  <Button />
</form>
```

---

## 7. KanbanBoard Component (Existing)

**Location:** `src/components/KanbanBoard.tsx`

- Dùng để hiển thị ứng viên theo stage
- Integration với badge colors
- Existing component - không thay đổi trong iteration này

---

## 8. Performance Optimization

### Implemented
1. **Reusable Components** - Badge, Card, Button dùng chung
2. **Tailwind CSS** - Zero JS overhead
3. **Server Components** - Data formatting on server
4. **Memoization** - Card components memoized
5. **Lazy Loading** - Link prefetching từ Next.js

### Best Practices
- Dùng line-clamp thay vì JS truncation
- Format dates trên server
- Minimize client-side state

---

## 9. Accessibility (A11y)

### Implemented
1. **Semantic HTML** - Proper heading hierarchy
2. **ARIA Labels** - Badges có title attributes
3. **Keyboard Navigation** - All interactive elements accessible
4. **Color Contrast** - WCAG AA compliant
5. **Focus States** - Visible focus indicators
6. **Skip Links** - Jump to main content

---

## 10. How to Use Improvements

### Import Badge for Status
```jsx
import { Badge } from '@/components/Badge';
import { getJobStatusBadgeClass } from '@/lib/formatters';

<Badge className={getJobStatusBadgeClass(status)}>
  {status}
</Badge>
```

### Format Candidate Count
```jsx
import { formatCandidateCount } from '@/lib/formatters';

<p>{formatCandidateCount(45)}</p>
```

### Create a Job Card
```jsx
import { Card, CardHeader, CardContent } from '@/components/Card';
import { Badge } from '@/components/Badge';
import { Button } from '@/components/Button';

<Card hover>
  <CardHeader title={job.title} />
  <CardContent>
    <p>{formatCandidateCount(job.apply_count)}</p>
  </CardContent>
</Card>
```

### Expandable Content
```jsx
import { Expandable } from '@/components/Expandable';

{isLongContent && (
  <Expandable summary="Xem chi tiết">
    {job.description}
  </Expandable>
)}
```

---

## 11. Component Usage Patterns

### Pattern 1: Status Display
```jsx
// Simple status
<Badge variant="success">Đang tuyển</Badge>

// Status with count
<Badge variant="primary">45 ứng tuyển</Badge>

// Status with icon
<Badge>{icon} {status}</Badge>
```

### Pattern 2: Data Lists
```jsx
// Job card in list
<Card hover>
  {/* Title */}
  {/* Metadata badges */}
  {/* Action button */}
</Card>
```

### Pattern 3: Forms
```jsx
// Search + filter
<form className="flex gap-3">
  <input placeholder="Search..." />
  <select>options</select>
  <Button type="submit">Filter</Button>
</form>
```

---

## 12. Future Enhancements

1. **Advanced Analytics Dashboard** - Job performance metrics
2. **Candidate Pipeline** - Visual candidate flow
3. **Bulk Actions** - Select multiple jobs
4. **Custom Workflows** - Define custom stages
5. **Export Reports** - CSV/PDF reports
6. **AI Recommendations** - Smart candidate matching
7. **Mobile App** - Native mobile experience
8. **Webhooks** - Real-time integrations

---

## 13. Testing Checklist

- [ ] Jobs load quickly with pagination
- [ ] Status badges display correct colors
- [ ] Search filters work correctly
- [ ] Empty states show appropriate messages
- [ ] Responsive layout on all screen sizes
- [ ] Links navigate correctly
- [ ] Badges display candidate counts properly
- [ ] Date formatting is consistent
- [ ] Keyboard navigation works
- [ ] Color contrast meets WCAG AA

---

## 14. Migration Guide (if updating existing pages)

### Before (Old Style)
```jsx
<div className="rounded border bg-white p-4">
  <div className="font-semibold">{job.title}</div>
  <div className="text-xs">{job.status}</div>
</div>
```

### After (New Style)
```jsx
<Card hover>
  <h3 className="font-semibold">{job.title}</h3>
  <Badge className={getJobStatusBadgeClass(job.status)}>
    {job.status}
  </Badge>
</Card>
```

---

**Questions?** Refer to component files in `src/components/` directory.
