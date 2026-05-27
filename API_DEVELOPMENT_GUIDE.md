# API Development Guide

## How to Add a New API Function

### Step 1: Define Your Types

Create or update types in `/types/{module}.ts`:

```typescript
// types/custom.ts
export interface CustomResource {
  id: string;
  name: string;
  created_at: string;
}

export interface CreateCustomInput {
  name: string;
  description?: string;
}

export interface Paginated<T> {
  data: T[];
  meta: {
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
}
```

### Step 2: Create Mock Data

Add mock data in `/mocks/{module}.ts`:

```typescript
// mocks/custom.ts
import type { CustomResource } from '@/types/custom';

export const mockCustomItems: CustomResource[] = [
  {
    id: 'custom_001',
    name: 'Item 1',
    created_at: new Date().toISOString(),
  },
  {
    id: 'custom_002',
    name: 'Item 2',
    created_at: new Date().toISOString(),
  },
];
```

### Step 3: Implement the API Module

Create or update `/lib/api/{module}.ts`:

```typescript
import { config } from '@/lib/config';
import { mockCustomItems } from '@/mocks/custom';
import type { CustomResource, CreateCustomInput, Paginated } from '@/types/custom';
import { apiFetch } from './client';

// List API
export async function listCustomItems(
  query: { q?: string; limit?: number; page?: number } = {}
): Promise<Paginated<CustomResource>> {
  if (config.useMock) {
    const filtered = mockCustomItems.filter(
      (item) => !query.q || item.name.toLowerCase().includes(query.q.toLowerCase())
    );
    return Promise.resolve({
      data: filtered,
      meta: {
        current_page: query.page ?? 1,
        last_page: 1,
        per_page: query.limit ?? 20,
        total: filtered.length,
      },
    });
  }
  return apiFetch<Paginated<CustomResource>>('/api/custom-items', {
    query: query as Record<string, string | number>,
  });
}

// Get Detail
export async function getCustomItem(id: string): Promise<CustomResource> {
  if (config.useMock) {
    const item = mockCustomItems.find((x) => x.id === id);
    if (!item) throw new Error('Item not found');
    return Promise.resolve(item);
  }
  return apiFetch<CustomResource>(`/api/custom-items/${encodeURIComponent(id)}`);
}

// Create
export async function createCustomItem(
  input: CreateCustomInput
): Promise<CustomResource> {
  if (config.useMock) {
    return Promise.resolve({
      id: `custom_mock_${Date.now()}`,
      name: input.name,
      created_at: new Date().toISOString(),
    });
  }
  return apiFetch<CustomResource>('/api/custom-items', {
    method: 'POST',
    body: input,
  });
}

// Update
export async function updateCustomItem(
  id: string,
  input: Partial<CreateCustomInput>
): Promise<CustomResource> {
  if (config.useMock) {
    const item = mockCustomItems.find((x) => x.id === id) ?? mockCustomItems[0];
    return Promise.resolve({ ...item, ...input });
  }
  return apiFetch<CustomResource>(
    `/api/custom-items/${encodeURIComponent(id)}`,
    { method: 'PUT', body: input }
  );
}

// Delete
export async function deleteCustomItem(id: string): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch(`/api/custom-items/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}
```

### Step 4: Export from Index

Update `/lib/api/index.ts`:

```typescript
export * as customApi from './custom';
```

### Step 5: Usage in Components

```typescript
import { customApi } from '@/lib/api';

// In a Server Component or Route Handler
const items = await customApi.listCustomItems({ q: 'search' });
const item = await customApi.getCustomItem('custom_001');
const newItem = await customApi.createCustomItem({ name: 'New Item' });
```

---

## API Function Patterns

### Pattern 1: List with Pagination & Filtering

```typescript
export async function listItems(
  query: { q?: string; status?: string; page?: number; limit?: number } = {}
): Promise<Paginated<ItemResource>> {
  if (config.useMock) {
    let filtered = mockItems;
    if (query.q) {
      filtered = filtered.filter(item =>
        item.title.toLowerCase().includes(query.q.toLowerCase())
      );
    }
    return Promise.resolve({
      data: filtered,
      meta: { /* pagination */ }
    });
  }
  return apiFetch<Paginated<ItemResource>>('/api/items', {
    query: query as Record<string, string | number>,
  });
}
```

### Pattern 2: Scoped to Parent Resource

```typescript
export async function listWorkspaceItems(
  workspaceId: string,
  query?: { q?: string }
): Promise<Paginated<ItemResource>> {
  if (config.useMock) return Promise.resolve(mockItems);
  return apiFetch<Paginated<ItemResource>>(
    `/api/workspaces/${workspaceId}/items`,
    { query }
  );
}
```

### Pattern 3: Action/State Change

```typescript
export async function approveItem(itemId: string): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch(`/api/items/${encodeURIComponent(itemId)}/approve`, {
    method: 'PATCH',
  });
}
```

### Pattern 4: Form Data Upload

```typescript
export async function uploadDocument(
  file: File,
  metadata: { name: string }
): Promise<DocumentResource> {
  // Get presigned URL first
  const presigned = await storageApi.getPresignedUrl({
    filename: file.name,
  });

  // Upload file
  await storageApi.uploadFile(presigned.url, file);

  // Save metadata
  return apiFetch<DocumentResource>('/api/documents', {
    method: 'POST',
    body: { ...metadata, file_url: presigned.public_url },
  });
}
```

---

## Error Handling

### Pattern: Try-Catch

```typescript
import { ApiClientError } from '@/lib/api';

try {
  const item = await customApi.getCustomItem(id);
} catch (error) {
  if (error instanceof ApiClientError) {
    if (error.status === 404) {
      console.log('Not found');
    } else if (error.status === 401) {
      console.log('Unauthorized');
    } else if (error.errors) {
      // Validation errors
      console.log(error.errors); // { field: ['error 1', 'error 2'] }
    }
  }
}
```

---

## Mock Mode Development

### Enable Mock Mode

Set in `/lib/config.ts`:

```typescript
export const config = {
  useMock: process.env.NEXT_PUBLIC_USE_MOCK === 'true',
  // ...
};
```

Or via environment variable:

```bash
NEXT_PUBLIC_USE_MOCK=true npm run dev
```

### Why Use Mock Mode?

1. **Fast Development** - No backend dependency
2. **Offline Work** - Develop without network
3. **Predictable Data** - Same data every time
4. **Testing** - Easy to test UI with fixtures
5. **Prototyping** - Rapid feature development

### When to Use Real API

1. After backend is deployed
2. Testing actual error scenarios
3. Performance testing
4. Integration testing
5. User acceptance testing

---

## Connecting to Real Backend

### Step 1: Update Config

```typescript
// lib/config.ts
export const config = {
  apiBaseUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000',
  apiHostOverride: process.env.NEXT_PUBLIC_API_HOST_OVERRIDE,
  useMock: process.env.NEXT_PUBLIC_USE_MOCK === 'true',
};
```

### Step 2: Set Environment Variables

Create `.env.local`:

```
NEXT_PUBLIC_API_URL=https://api.yourapp.com
NEXT_PUBLIC_USE_MOCK=false
```

### Step 3: Update Authentication

```typescript
// lib/api/client.ts - getBrowserToken()
async function getBrowserToken(): Promise<string | null> {
  if (typeof window === 'undefined') return null;
  
  // Replace with your auth provider
  const session = await getSession(); // NextAuth, Keycloak, etc.
  return session?.accessToken ?? null;
}
```

### Step 4: Test Connection

```bash
# Start with mock
NEXT_PUBLIC_USE_MOCK=true npm run dev

# Switch to real API
NEXT_PUBLIC_USE_MOCK=false npm run dev
```

---

## Common API Patterns in This Project

### Pattern: Paginated List

Most list endpoints return paginated responses:

```typescript
interface Paginated<T> {
  data: T[];
  meta: {
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
}
```

### Pattern: Nested Resources

Job workspace jobs are scoped to workspace:

```typescript
// Get jobs for a workspace
await jobApi.listWorkspaceJobs(workspaceId, filters);

// Pattern: /api/workspaces/{id}/resource
```

### Pattern: Array Query Parameters

Laravel-style array parameters:

```typescript
// For: job_types[]=1&job_types[]=2
const url = new URL('...');
for (const id of filters.job_types) {
  url.searchParams.append('job_types[]', String(id));
}
```

### Pattern: Wrapper Response

Some endpoints wrap data:

```typescript
// Response: { data: [...], message: "..." }
const r = await apiFetch<{ data: T[] }>('/api/items');
return r.data; // Extract data from wrapper
```

---

## Testing API Functions

### Unit Test Pattern

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import * as customApi from '@/lib/api/custom';

describe('customApi', () => {
  beforeEach(() => {
    // Mock config.useMock = true for predictable tests
  });

  it('should list items', async () => {
    const result = await customApi.listCustomItems();
    expect(result.data).toHaveLength(2);
    expect(result.meta.total).toBe(2);
  });

  it('should filter items by search', async () => {
    const result = await customApi.listCustomItems({ q: 'Item 1' });
    expect(result.data).toHaveLength(1);
    expect(result.data[0].name).toBe('Item 1');
  });

  it('should create item', async () => {
    const newItem = await customApi.createCustomItem({ name: 'New' });
    expect(newItem.id).toBeDefined();
    expect(newItem.name).toBe('New');
  });
});
```

---

## Best Practices

1. **Always define types first** - Types guide implementation
2. **Always create mock data** - Enables offline development
3. **Use encodeURIComponent()** - Safe URL encoding
4. **Handle pagination** - Don't hardcode limits
5. **Support filtering** - Query parameters for search/filter
6. **Consistent naming** - list*, get*, create*, update*, delete*
7. **Error handling** - Use ApiClientError
8. **Mock mode first** - Develop with mocks, test with real API later
9. **Document parameters** - Clear JSDoc comments
10. **Batch related calls** - Group related functions in same module

---

## Troubleshooting

### "API not found" in mock mode
- Ensure `config.useMock` is true
- Check mock data exists in `/mocks/{module}.ts`
- Verify function returns mock data correctly

### 401 Unauthorized
- Token not set in localStorage
- Token expired
- Update authentication to real auth provider

### CORS errors
- Backend not allowing frontend origin
- Missing CORS headers
- Use API proxy in development

### Network timeout
- Backend server down
- Network connectivity issue
- Increase timeout in request options

---

## Reference

- **API Client:** `/lib/api/client.ts`
- **All Modules:** `/lib/api/`
- **Mock Data:** `/mocks/`
- **Types:** `/types/`
- **Config:** `/lib/config.ts`

