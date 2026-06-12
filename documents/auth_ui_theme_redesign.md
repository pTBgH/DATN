# Auth UI Theme Redesign Summary

## Overview
Updated login and signup pages for both rct_frontend and atd_frontend to match the system's design theme (indigo/purple primary, cyan secondary, light gray background).

## Changes Made

### Color System Updated
- **Background**: Light gray (#fafafa) instead of orange (#FF6B4A)
- **Primary**: Indigo/Purple (#312e81) for buttons and links
- **Secondary**: Cyan (#06b6d4) for accents
- **Text**: Proper foreground/muted colors from design tokens
- **Borders**: Subtle muted-light borders (#e5e7eb)

### Pages Redesigned
1. **rct_frontend/src/app/login/page.tsx**
   - Theme-compliant form card with rounded corners (rounded-2xl)
   - Serif font (4xl) for "Đăng Nhập" heading
   - White card on light gray background (not orange)
   - Google button with proper styling

2. **rct_frontend/src/app/signup/page.tsx**
   - Same theme treatment as login
   - Password helper text "Tối thiểu 8 ký tự"
   - Email/password/confirm password form
   - Google signup button

3. **atd_frontend/src/app/login/page.tsx**
   - Candidate-specific heading: "Tìm công việc phù hợp với bạn"
   - Redirects to `/browse` instead of `/recruiter`
   - Same premium styling

4. **atd_frontend/src/app/signup/page.tsx**
   - Candidate-specific heading: "Tạo tài khoản và bắt đầu tìm việc"
   - Redirects to `/browse` on signup success
   - Same premium styling

### UI Components
- **Form fields**: Tailwind shadow-md cards with proper spacing (p-8)
- **Buttons**: Full-width with hover states (hover:bg-brand-dark)
- **Links**: Brand color with proper transitions
- **Divider**: "HOẶC" divider with muted borders
- **Google button**: Full-width with Google SVG icon
- **Responsive**: Works on mobile and desktop (max-w-md, px-4 py-8)

### Key Design Decisions
- ✅ Removed hardcoded orange (#FF6B4A) background
- ✅ Used CSS variables from theme (--primary, --background, etc.)
- ✅ Consistent with homepage styling (serif headings, rounded cards)
- ✅ Proper label visibility for accessibility
- ✅ Error messages with red background
- ✅ Terms & Privacy links at bottom

## Verification
- ✅ Both frontends compile without TypeScript errors
- ✅ Theme colors match globals.css
- ✅ Responsive layout works on mobile/desktop
- ✅ Google button placeholder ready for Keycloak OAuth integration

## Next Steps
1. Configure Keycloak Google IdP for OAuth login/signup
2. Implement `handleGoogleLogin()` and `handleGoogleSignup()` functions
3. Test password reset flow at `/forgot-password`
