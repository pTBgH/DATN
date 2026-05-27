# ATD Frontend (Ứng Viên) - UI/UX Improvements Documentation

## Tổng Quan Cải Thiện

Tài liệu này ghi lại toàn bộ những cải thiện UI/UX được thực hiện trên ATD Frontend (phần mềm dành cho ứng viên) để nâng cao trải nghiệm người dùng, hiển thị dữ liệu tốt hơn, và xử lý các trường hợp dữ liệu quá dài.

**Ngày cập nhật:** 2024
**Phiên bản:** 1.0

---

## 1. Utility Functions (`src/lib/formatters.ts`)

### Mục đích
Tập hợp các hàm hỗ trợ định dạng dữ liệu để hiển thị nhất quán trên toàn ứng dụng.

### Các Hàm Chính

#### `truncateText(text, maxLength)`
- **Mục đích:** Cắt ngắn văn bản dài và thêm "..."
- **Sử dụng:** Hiển thị mô tả công việc, yêu cầu, quyền lợi
- **Ví dụ:**
  ```typescript
  truncateText("Mô tả rất dài...", 150) // "Mô tả rất dài..."
  ```

#### `formatDate(date, format)`
- **Mục đích:** Định dạng ngày tháng theo kiểu khác nhau
- **Format types:**
  - `short`: "Jan 15, 2024"
  - `long`: "Tuesday, January 15, 2024"
  - `relative`: "5d ago" hoặc "Just now"
- **Ví dụ:**
  ```typescript
  formatDate("2024-01-10", "relative") // "5d ago"
  ```

#### `getStatusBadgeClass(status)`
- **Mục đích:** Trả về CSS classes cho status badge
- **Hỗ trợ trạng thái:** Applied, Viewed, Shortlisted, Interview, Offered, Rejected, Withdrawn
- **Ví dụ:**
  ```typescript
  getStatusBadgeClass("Offered") // "bg-emerald-100 text-emerald-800"
  ```

#### `getInitials(name)`
- **Mục đích:** Tạo chữ viết tắt từ tên đầy đủ
- **Ví dụ:**
  ```typescript
  getInitials("John Doe") // "JD"
  ```

---

## 2. Reusable Components

### Badge Component (`src/components/Badge.tsx`)
**Mục đích:** Hiển thị trạng thái, tags, labels với màu sắc khác nhau

**Variants:**
- `default` - Xám
- `success` - Xanh lá
- `warning` - Vàng cam
- `error` - Đỏ
- `info` - Xanh dương
- `primary` - Cyan (thương hiệu)

**Sizes:** `sm` | `md` | `lg`

**Ví dụ sử dụng:**
```jsx
<Badge variant="primary" size="md">✓ Đã ứng tuyển</Badge>
<Badge variant="success">Nhận việc</Badge>
<Badge variant="error">Bị từ chối</Badge>
```

### Card Components (`src/components/Card.tsx`)
**Bao gồm:**
- `Card` - Container chính
- `CardHeader` - Tiêu đề + mô tả
- `CardContent` - Nội dung chính
- `CardFooter` - Phần hành động ở cuối

**Props chính:**
- `hover` - Thêm hiệu ứng hover
- `noBorder` - Ẩn đường viền
- `className` - CSS tùy chỉnh

**Ví dụ:**
```jsx
<Card hover>
  <CardHeader title="Vị trí tuyển dụng" />
  <CardContent>Mô tả công việc...</CardContent>
  <CardFooter>
    <Button>Chi tiết</Button>
  </CardFooter>
</Card>
```

### Button Component (`src/components/Button.tsx`)
**Variants:** `primary` | `secondary` | `outline` | `ghost` | `danger`
**Sizes:** `sm` | `md` | `lg`
**Props:** `isLoading` - Hiển thị loading spinner

**Ví dụ:**
```jsx
<Button variant="primary" size="lg" isLoading={false}>
  Ứng tuyển ngay
</Button>
```

### Expandable Component (`src/components/Expandable.tsx`)
**Mục đích:** Hiển thị/ẩn nội dung dài một cách mượt mà
**Hữu ích cho:** Mô tả công việc, yêu cầu, quyền lợi khi quá dài

**Ví dụ:**
```jsx
<Expandable summary="Xem chi tiết">
  Nội dung mô tả dài...
</Expandable>
```

---

## 3. Page Improvements

### 3.1 Jobs List Page (`src/app/jobs/page.tsx`)

#### Cải Thiện:
1. **Tiêu đề & Mô tả trang**
   - Thêm tiêu đề lớn, hấp dẫn: "Khám phá Việc Làm"
   - Thêm mô tả trang con giải thích mục đích

2. **Search Form**
   - Input trường hợp tìm kiếm với style hiện đại
   - Placeholder chi tiết hơn
   - Focus states rõ ràng

3. **Result Counter**
   - Hiển thị dạng gradient background
   - Số lượng kết quả nổi bật

4. **Job Cards**
   - Dùng Card component với hover effects
   - Hiển thị logic:
     - Tiêu đề công việc (line-clamp-2)
     - Tên công ty
     - Mô tả (cắt ngắn 150 ký tự)
     - Mức lương (highlight cyan)
     - Meta: lượt xem + deadline

5. **Empty State**
   - Hiển thị thông báo thân thiện khi không có kết quả

#### Code Changes:
```typescript
// Before: Simple list
// After: Rich card layout with:
- Better typography hierarchy
- Status badges
- Truncated descriptions
- Visual emphasis on salary
- Relative deadlines
```

### 3.2 Job Detail Page (`src/app/jobs/[id]/page.tsx`)

#### Cải Thiện:
1. **Header Section**
   - Tiêu đề lớn (text-4xl)
   - Company name prominent
   - Status badges (status + applies + views)
   - Salary highlight trong gradient box
   - CTA button "Ứng tuyển ngay"

2. **Content Sections**
   - 3 sections: Mô tả, Yêu cầu, Quyền lợi
   - Tự động dùng `Expandable` nếu nội dung > 500 ký tự
   - Icons cho từng section (📋 ✓ 🎁)

3. **Statistics Card**
   - Hiển thị tổng lượt xem và ứng tuyển
   - Grid layout 2 cột
   - Số lớn, dễ nhìn

#### Code Changes:
```typescript
// Auto-expand logic for long content
const isLongContent = body.length > 500;
{isLongContent ? (
  <Expandable summary="Xem chi tiết">{body}</Expandable>
) : (
  body
)}
```

### 3.3 Applications Page (`src/app/applications/page.tsx`)

#### Cải Thiện:
1. **Page Header**
   - Tiêu đề rõ ràng: "Đơn Ứng Tuyển Của Tôi"
   - Mô tả mục đích trang

2. **Empty State**
   - Emoji icon 📝
   - Tin nhắn thân thiện
   - CTA button tới trang jobs

3. **Application Cards**
   - Dùng Card component với hover
   - Hiển thị:
     - Tiêu đề công việc (link)
     - Công ty
     - Thời gian ứng tuyển (chi tiết)
     - Status badge với emoji
   - Responsive layout

4. **Status Mapping**
   - Hiển thị emoji cho từng trạng thái
   - Labels tiếng Việt rõ ràng
   - Color-coded badges

#### Status Emoji Map:
```
Applied → ✓ Đã ứng tuyển
Viewed → 👁️ Đã xem
Shortlisted → ⭐ Lọc sơ
Interview → 📞 Phỏng vấn
Offered → 🎉 Nhận việc
Rejected → ❌ Từ chối
Withdrawn → 🔙 Rút lại
```

---

## 4. Design System

### Color Palette
```css
Primary: cyan-600 (#0891b2) - Thương hiệu chính
Success: green-600 (#16a34a) - Thành công
Warning: amber-600 (#b45309) - Cảnh báo
Error: red-600 (#dc2626) - Lỗi
Info: blue-600 (#2563eb) - Thông tin
Neutral: slate-* - Neutral backgrounds
```

### Typography
- **Headings:** text-2xl to text-4xl, font-bold/semibold
- **Body:** text-base/sm, font-normal, text-slate-*
- **Labels:** text-xs/sm, font-medium, uppercase tracking

### Spacing
- Gaps: `gap-3`, `gap-4`, `gap-6`
- Padding: `p-4`, `p-5`, `px-4 py-2.5`
- Margins: `mt-2`, `mb-4`, `space-y-*`

### Rounded Corners
- Standard: `rounded-lg` - 8px
- Small: `rounded` - 4px
- Large: Không dùng (dùng lg)

---

## 5. Xử Lý Dữ Liệu Quá Dài

### Chiến Lược

| Trường dữ liệu | Chiến lược | Max chiều dài |
|---|---|---|
| Job title | line-clamp-2 | 100 ký tự |
| Job description (list) | truncateText() | 150 ký tự |
| Description (detail) | Expandable nếu > 500 | Unlimited |
| Company name | Normal | 50 ký tự |
| Status | Badge | Dynamic |
| Location | Format + Normal | 50 ký tự |

### Ví dụ Implementasi

**Truncate with indicator:**
```jsx
{j.description && (
  <p className="line-clamp-2 text-sm text-slate-600">
    {truncateText(j.description, 150)}
  </p>
)}
```

**Expandable sections:**
```jsx
<Expandable summary="Xem chi tiết">
  {longContent}
</Expandable>
```

---

## 6. Responsive Design

### Breakpoints Used
- **Mobile (default):** < 640px
- **Tablet (sm):** ≥ 640px
- **Desktop (md):** ≥ 768px
- **Large (lg):** ≥ 1024px

### Layout Adjustments
```jsx
// Job detail - side by side on desktop
<div className="flex flex-col gap-3 sm:flex-row sm:items-center">
  {/* Salary */}
  {/* Deadline */}
  {/* CTA Button */}
</div>
```

---

## 7. Performance Optimization

### Implemented
1. **Component Reusability** - Badge, Card, Button tái sử dụng
2. **Tailwind CSS** - Zero JS overhead cho styles
3. **Server Components** - Rendering trên server, không load JS thêm
4. **Link Prefetching** - Next.js tự động prefetch links

### Best Practices
- Dùng `line-clamp-*` thay vì JS truncation
- Dùng `details` HTML element cho Expandable (không cần JS)
- Server-render tất cả data formatting

---

## 8. Accessibility (A11y)

### Implemented
1. **Semantic HTML** - `<article>`, `<section>`, `<header>` tags
2. **ARIA Labels** - Badges có title attributes
3. **Keyboard Navigation** - Tất cả buttons clickable
4. **Color Contrast** - Badges với sufficient contrast ratio
5. **Details/Summary** - Native HTML expandable

---

## 9. How to Use

### Thêm Badge vào trang mới
```jsx
import { Badge } from '@/components/Badge';

<Badge variant="primary">Status</Badge>
<Badge variant="success" size="lg">Success</Badge>
```

### Dùng Formatter Functions
```jsx
import { truncateText, formatDate, getStatusBadgeClass } from '@/lib/formatters';

const shortText = truncateText(longText, 150);
const date = formatDate(new Date(), 'relative');
const statusClass = getStatusBadgeClass('Offered');
```

### Tạo expandable content
```jsx
import { Expandable } from '@/components/Expandable';

<Expandable summary="Xem thêm">
  Long content here...
</Expandable>
```

---

## 10. Future Enhancements

1. **Thêm animations** - Page transitions, card stagger
2. **Dark mode** - Theme toggle
3. **Saved jobs** - Bookmark functionality
4. **Advanced filters** - Location, salary, job type
5. **Application history** - Timeline view
6. **Notifications** - Real-time status updates

---

## 11. Testing Checklist

- [ ] Jobs list loads quickly
- [ ] Long descriptions display correctly with truncation
- [ ] Expandable sections work smoothly
- [ ] Status badges show correct colors
- [ ] Responsive layout on mobile/tablet/desktop
- [ ] Links navigate correctly
- [ ] Empty states display properly
- [ ] Date formatting is correct (Vietnamese)

---

**Questions?** Refer to component documentation in individual component files.
