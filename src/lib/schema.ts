import { z } from 'zod';

const SeoSchema = z.object({
  title: z.string().optional(),
  description: z.string().optional(),
  socialImage: z.string().url().optional(),
});

export const ImageMediaSchema = z.object({
  type: z.literal('image'),
  url: z.string().url(),
  alt: z.string().default(''),
  caption: z.string().optional(),
  width: z.number().int().positive().optional(),
  height: z.number().int().positive().optional(),
  srcset: z.string().optional(),
  sizes: z.string().optional(),
});

export const VideoMediaSchema = z.object({
  type: z.literal('video'),
  url: z.string().url(),
  mimeType: z.string().optional(),
  caption: z.string().optional(),
  width: z.number().int().positive().optional(),
  height: z.number().int().positive().optional(),
  poster: ImageMediaSchema.optional(),
});

export const EmbedMediaSchema = z.object({
  type: z.literal('embed'),
  provider: z.enum(['youtube', 'vimeo']),
  url: z.string().url(),
  caption: z.string().optional(),
  title: z.string().optional(),
});

export const MediaItemSchema = z.discriminatedUnion('type', [
  ImageMediaSchema,
  VideoMediaSchema,
  EmbedMediaSchema,
]);

export const ShowSchema = z.object({
  id: z.union([z.string(), z.number()]).transform(String),
  slug: z.string().min(1),
  title: z.string().min(1),
  showDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  directors: z.array(z.string().min(1)).min(1),
  companies: z.array(z.string().min(1)).min(1),
  role: z.string().min(1),
  featured: z.boolean().default(false),
  menuOrder: z.number().int().optional(),
  blurbMarkdown: z.string().optional(),
  tileImage: ImageMediaSchema.optional(),
  media: z.array(MediaItemSchema).default([]),
  caseStudyMarkdown: z.string().optional(),
  seo: SeoSchema.optional(),
}).superRefine((show, ctx) => {
  if (!show.featured) return;

  if (!show.tileImage) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Featured shows require tileImage.',
      path: ['tileImage'],
    });
  }

  if (!show.blurbMarkdown?.trim()) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Featured shows require blurbMarkdown.',
      path: ['blurbMarkdown'],
    });
  }
});

export const PageSchema = z.object({
  id: z.union([z.string(), z.number()]).transform(String),
  slug: z.string().min(1),
  title: z.string().min(1),
  markdown: z.string(),
  seo: SeoSchema.optional(),
});

export const SiteSettingsSchema = z.object({
  seo: SeoSchema.optional(),
  homepageHeroVideo: VideoMediaSchema.optional(),
  resumeIntroMarkdown: z.string().optional(),
  resumeOutroMarkdown: z.string().optional(),
});

export const BuildPayloadSchema = z.object({
  schemaVersion: z.literal(1),
  generatedAt: z.string(),
  site: SiteSettingsSchema.default({}),
  pages: z.array(PageSchema).default([]),
  shows: z.array(ShowSchema).default([]),
});

export type BuildPayload = z.infer<typeof BuildPayloadSchema>;
export type MediaItem = z.infer<typeof MediaItemSchema>;
export type Show = z.infer<typeof ShowSchema>;
export type Page = z.infer<typeof PageSchema>;
