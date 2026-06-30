import { marked } from 'marked';
import sanitizeHtml from 'sanitize-html';

marked.use({
  gfm: true,
  breaks: false,
});

const allowedTags = [
  'a',
  'blockquote',
  'br',
  'code',
  'em',
  'h2',
  'h3',
  'h4',
  'hr',
  'li',
  'ol',
  'p',
  'pre',
  'strong',
  'ul',
];

export async function renderMarkdown(markdown = ''): Promise<string> {
  const html = await marked.parse(markdown);

  return sanitizeHtml(html, {
    allowedTags,
    allowedAttributes: {
      a: ['href', 'title', 'target', 'rel'],
    },
    allowedSchemes: ['http', 'https', 'mailto'],
    transformTags: {
      a: (_tagName, attribs) => {
        const isInternal = attribs.href?.startsWith('/');
        const cleanAttribs: Record<string, string> = {
          ...attribs,
          rel: 'nofollow noopener noreferrer',
        };

        if (!isInternal) {
          cleanAttribs.target = '_blank';
        }

        return {
          tagName: 'a',
          attribs: cleanAttribs,
        };
      },
    },
  });
}
