import crypto from 'node:crypto';
import path from 'node:path';
import { readFile } from 'node:fs/promises';

import * as cheerio from 'cheerio';
import JSZip from 'jszip';

import type { ParsedEpubDocument, SourceSection } from '../domain.js';

function normalizeText(input: string): string {
  return input
    .replace(/\u00a0/g, ' ')
    .replace(/\r/g, '\n')
    .split('\n')
    .map((line) => line.replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .join('\n');
}

function stripFragment(href: string): string {
  return href.split('#')[0];
}

function resolveZipPath(basePath: string, relativeHref: string): string {
  if (!relativeHref) {
    return basePath;
  }

  if (relativeHref.startsWith('/')) {
    return relativeHref.slice(1);
  }

  return path.posix.normalize(path.posix.join(path.posix.dirname(basePath), relativeHref));
}

async function readZipText(zip: JSZip, filePath: string): Promise<string | null> {
  const file = zip.file(filePath);
  return file ? file.async('text') : null;
}

function pickTitle($: cheerio.CheerioAPI, fallback: string): string {
  const selectors = ['h1', 'h2', 'h3.title', 'h3', 'title'];
  for (const selector of selectors) {
    const text = $(selector).first().text().trim();
    if (text.length > 0) {
      return text.slice(0, 120);
    }
  }

  return fallback;
}

function extractBodyText($: cheerio.CheerioAPI): string {
  $('script,style,noscript,template,iframe,svg,path,div.mbp_pagebreak,sup').remove();
  $('a[href^="#filepos"]').remove();
  $('img').remove();
  const nodes = $('body').find('h1,h2,h3,h4,p,li,blockquote');
  if (nodes.length > 0) {
    const blocks = nodes
      .map((_, element) => $(element).text())
      .get()
      .map((text) => normalizeText(text))
      .filter((text) => text.length > 0);
    return normalizeText(blocks.join('\n'));
  }

  return normalizeText($('body').text());
}

async function parseTocMap(
  zip: JSZip,
  opfPath: string,
  opf$: cheerio.CheerioAPI,
  manifest: Map<string, { href: string; mediaType: string; properties?: string }>,
): Promise<Map<string, string>> {
  const toc = new Map<string, string>();
  const opfDir = path.posix.dirname(opfPath);

  const navItem = [...manifest.values()].find((item) => item.properties?.includes('nav'));
  if (navItem) {
    const navPath = resolveZipPath(opfPath, navItem.href);
    const navText = await readZipText(zip, navPath);
    if (navText) {
      const $ = cheerio.load(navText, { xmlMode: true });
      $('a[href]').each((_, element) => {
        const href = $(element).attr('href');
        const label = normalizeText($(element).text());
        if (href && label) {
          toc.set(resolveZipPath(navPath, stripFragment(href)), label);
        }
      });
    }
  }

  const ncxId = opf$('spine').attr('toc');
  if (ncxId && manifest.has(ncxId)) {
    const ncxPath = resolveZipPath(opfPath, manifest.get(ncxId)!.href);
    const ncxText = await readZipText(zip, ncxPath);
    if (ncxText) {
      const $ = cheerio.load(ncxText, { xmlMode: true });
      $('navPoint').each((_, element) => {
        const label = normalizeText($(element).find('text').first().text());
        const src = $(element).find('content').attr('src');
        if (label && src) {
          toc.set(resolveZipPath(ncxPath, stripFragment(src)), label);
        }
      });
    }
  }

  return toc;
}

export async function parseEpub(filePath: string): Promise<{ document: ParsedEpubDocument; fileHash: string }> {
  const buffer = await readFile(filePath);
  const fileHash = crypto.createHash('sha256').update(buffer).digest('hex');
  const zip = await JSZip.loadAsync(buffer);

  const containerText = await readZipText(zip, 'META-INF/container.xml');
  if (!containerText) {
    throw new Error(`EPUB 缺少 container.xml: ${filePath}`);
  }

  const container$ = cheerio.load(containerText, { xmlMode: true });
  const opfPath = container$('rootfile').attr('full-path');
  if (!opfPath) {
    throw new Error(`EPUB 缺少 OPF 路径: ${filePath}`);
  }

  const opfText = await readZipText(zip, opfPath);
  if (!opfText) {
    throw new Error(`EPUB 无法读取 OPF: ${opfPath}`);
  }

  const opf$ = cheerio.load(opfText, { xmlMode: true });
  const title =
    normalizeText(opf$('metadata > title, metadata > dc\\:title').first().text()) ||
    path.basename(filePath, '.epub');
  const author = normalizeText(opf$('metadata > creator, metadata > dc\\:creator').first().text());

  const manifest = new Map<string, { href: string; mediaType: string; properties?: string }>();
  opf$('manifest > item').each((_, element) => {
    const id = opf$(element).attr('id');
    const href = opf$(element).attr('href');
    const mediaType = opf$(element).attr('media-type');
    if (id && href && mediaType) {
      manifest.set(id, {
        href,
        mediaType,
        properties: opf$(element).attr('properties') ?? undefined,
      });
    }
  });

  const tocMap = await parseTocMap(zip, opfPath, opf$, manifest);
  const sections: SourceSection[] = [];
  const opfDir = path.posix.dirname(opfPath);

  opf$('spine > itemref').each((_, element) => {
    const idref = opf$(element).attr('idref');
    if (!idref || !manifest.has(idref)) {
      return;
    }

    const item = manifest.get(idref)!;
    if (!item.mediaType.includes('html') && !item.mediaType.includes('xhtml')) {
      return;
    }

    const resolvedPath = path.posix.normalize(path.posix.join(opfDir, item.href));
    sections.push({
      ordinal: sections.length + 1,
      title: resolvedPath,
      href: resolvedPath,
      rawText: '',
      excerpt: '',
    });
  });

  const extractedSections: SourceSection[] = [];
  for (const section of sections) {
    const html = await readZipText(zip, section.href!);
    if (!html) {
      continue;
    }

    const $ = cheerio.load(html, { xmlMode: true });
    const rawText = extractBodyText($);
    if (rawText.length < 120) {
      continue;
    }

    const tocTitle = tocMap.get(section.href!);
    const fallbackTitle = tocTitle ?? path.basename(section.href!, path.extname(section.href!));
    const titleFromDoc = tocTitle ?? pickTitle($, fallbackTitle);

    extractedSections.push({
      ordinal: extractedSections.length + 1,
      title: titleFromDoc,
      href: section.href,
      rawText,
      excerpt: rawText.slice(0, 700),
    });
  }

  const mergedSections: SourceSection[] = [];
  for (let index = 0; index < extractedSections.length; index += 1) {
    const current = extractedSections[index];
    const next = extractedSections[index + 1];

    const chapterMarker = /^(第[\d一二三四五六七八九十百零]+[章节]|序章|楔子|引言|导言|简介)/.test(current.title);
    const looksLikeWrapper =
      current.rawText.length < 260 &&
      Boolean(next) &&
      next.rawText.length > 500 &&
      (chapterMarker || current.rawText.replace(/\n/g, '').length < current.title.length + 120);

    if (looksLikeWrapper && next) {
      mergedSections.push({
        ordinal: mergedSections.length + 1,
        title: current.title,
        href: current.href,
        rawText: `${current.rawText}\n${next.rawText}`,
        excerpt: `${current.rawText}\n${next.excerpt}`.slice(0, 700),
      });
      index += 1;
      continue;
    }

    if (current.rawText.length < 80) {
      continue;
    }

    mergedSections.push({
      ...current,
      ordinal: mergedSections.length + 1,
    });
  }

  if (mergedSections.length === 0) {
    throw new Error(`EPUB 未提取到有效章节: ${filePath}`);
  }

  return {
    fileHash,
    document: {
      title,
      author,
      sourceType: 'epub',
      metadata: {
        fileName: path.basename(filePath),
        opfPath,
        sectionCount: mergedSections.length,
      },
      sections: mergedSections,
    },
  };
}
