import { BuildPayloadSchema, type BuildPayload, type Show } from './schema';
import { Buffer } from 'node:buffer';

let cachedPayload: BuildPayload | undefined;

export async function getPortfolioData(): Promise<BuildPayload> {
  if (cachedPayload) return cachedPayload;

  const endpoint = process.env.CMS_BUILD_ENDPOINT;
  const token = process.env.CMS_BUILD_TOKEN;

  if (!endpoint || !token) {
    throw new Error('CMS_BUILD_ENDPOINT and CMS_BUILD_TOKEN are required to build the portfolio.');
  }

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`portfolio:${token}`).toString('base64')}`,
      'X-Portfolio-Build-Token': token,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({ token }),
  });

  if (!response.ok) {
    throw new Error(`CMS build endpoint returned ${response.status} ${response.statusText}`);
  }

  const json = await response.json();
  cachedPayload = BuildPayloadSchema.parse(json);
  return cachedPayload;
}

export function sortShowsForResume(shows: Show[]): Show[] {
  return [...shows].sort((a, b) => b.showDate.localeCompare(a.showDate));
}

export function sortFeaturedShows(shows: Show[]): Show[] {
  return shows
    .filter((show) => show.featured)
    .sort((a, b) => {
      const aOrder = a.menuOrder ?? Number.MAX_SAFE_INTEGER;
      const bOrder = b.menuOrder ?? Number.MAX_SAFE_INTEGER;

      if (aOrder !== bOrder) return aOrder - bOrder;
      return b.showDate.localeCompare(a.showDate);
    });
}

export function formatShowDate(showDate: string): string {
  const [year, month] = showDate.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, 1));

  return new Intl.DateTimeFormat('en-US', {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(date);
}
