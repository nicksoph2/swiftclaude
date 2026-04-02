# personal-site

My personal website and blog — Next.js 14 App Router, TypeScript, Tailwind CSS.
Hosted on Vercel. Content written in MDX.

## Commands

```bash
npm run dev        # Start dev server (port 3000)
npm run build      # Production build
npm run lint       # ESLint
npm run format     # Prettier
npm run typecheck  # tsc --noEmit
```

## Stack

- **Framework**: Next.js 14 (App Router)
- **Styling**: Tailwind CSS + CSS Modules for component-specific styles
- **Content**: MDX via `@next/mdx` — posts live in `content/posts/`
- **Deployment**: Vercel (auto-deploys from `main`)

## Layout

```
app/
  layout.tsx        ← Root layout, font loading, global metadata
  page.tsx          ← Home page
  blog/
    page.tsx        ← Blog index
    [slug]/
      page.tsx      ← Individual post
  about/page.tsx
components/
  ui/               ← Generic reusable components
  blog/             ← Blog-specific components
content/
  posts/            ← MDX blog posts (YYYY-MM-DD-slug.mdx)
public/
  images/
lib/
  posts.ts          ← Helpers for loading and parsing MDX posts
  metadata.ts       ← Shared metadata helpers
```

## Conventions

- Server Components by default; add `"use client"` only when needed (interactivity, hooks)
- No `pages/` directory — everything uses the App Router
- Images: use `next/image` with explicit `width` and `height` always
- Keep components small — if a component file exceeds ~100 lines, split it
- No inline styles — use Tailwind classes or CSS Modules

## Blog posts

MDX files in `content/posts/` require this frontmatter:

```yaml
---
title: "Post title"
date: "2025-03-15"
excerpt: "One sentence description for the blog index."
tags: ["nextjs", "typescript"]
published: true
---
```

Draft posts use `published: false` and are excluded from the build.

## Deployment

Push to `main` triggers a Vercel preview. Merging a PR to `main` deploys to production.
Environment variables are managed in the Vercel dashboard — never commit them.
