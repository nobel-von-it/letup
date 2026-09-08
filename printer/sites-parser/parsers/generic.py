"""
Generic Article Parser
Universal fallback extractor using HTML5 semantics, JSON-LD, and OpenGraph metadata.
"""
import json
from typing import List, Tuple
from bs4 import BeautifulSoup

from .base import BaseParser, Article, clean_inline_html


class GenericParser(BaseParser):
    name: str = "generic"
    site_display_name: str = "Article"
    domains: List[str] = []

    def extract(self, soup: BeautifulSoup, source_url: str, raw_html: str) -> Article:
        # 1. JSON-LD check
        article_meta = {}
        for script in soup.find_all("script", type="application/ld+json"):
            try:
                data = json.loads(script.string)
                if isinstance(data, dict):
                    if data.get("@type") in ["Article", "NewsArticle", "BlogPosting", "TechArticle"]:
                        article_meta = data
                        break
                    elif "@graph" in data:
                        for item in data["@graph"]:
                            if item.get("@type") in ["Article", "NewsArticle", "BlogPosting"]:
                                article_meta = item
                                break
            except Exception:
                pass

        # Title
        title = ""
        h1 = soup.find("h1")
        if h1:
            title = clean_inline_html(h1)
        elif article_meta.get("headline"):
            title = article_meta["headline"]
        else:
            og_title = soup.find("meta", property="og:title")
            if og_title and og_title.get("content"):
                title = og_title["content"]
            elif soup.title:
                title = soup.title.get_text().split("|")[0].split("-")[0].strip()

        # Subtitle
        subtitle = ""
        og_desc = soup.find("meta", property="og:description") or soup.find("meta", attrs={"name": "description"})
        if og_desc and og_desc.get("content"):
            subtitle = og_desc["content"].strip()
        elif article_meta.get("description"):
            subtitle = article_meta["description"].strip()

        # Author
        author = ""
        if article_meta.get("author"):
            auth_val = article_meta["author"]
            if isinstance(auth_val, list) and auth_val:
                names = [a.get("name", "") if isinstance(a, dict) else str(a) for a in auth_val]
                author = ", ".join(filter(None, names))
            elif isinstance(auth_val, dict):
                author = auth_val.get("name", "")
            elif isinstance(auth_val, str):
                author = auth_val

        if not author:
            meta_auth = soup.find("meta", attrs={"name": "author"})
            if meta_auth and meta_auth.get("content"):
                author = meta_auth["content"].strip()

        if not author:
            byline = soup.select_one(".byline, .author, [rel='author'], [itemprop='author']")
            if byline:
                author = clean_inline_html(byline)

        # Date
        date = ""
        if article_meta.get("datePublished"):
            date = str(article_meta["datePublished"]).split("T")[0]
        if not date:
            date_meta = soup.find("meta", property="article:published_time") or soup.find("meta", attrs={"name": "date"})
            if date_meta and date_meta.get("content"):
                date = date_meta["content"].split("T")[0]
        if not date:
            time_el = soup.find("time")
            if time_el:
                date = time_el.get("datetime", time_el.get_text(strip=True)).split("T")[0]

        # Site name
        site_name = ""
        og_site = soup.find("meta", property="og:site_name")
        if og_site and og_site.get("content"):
            site_name = og_site["content"].strip()

        # Lead image
        lead_image = None
        lead_caption = ""
        og_img = soup.find("meta", property="og:image")
        if og_img and og_img.get("content"):
            lead_image = og_img["content"]

        # Content container
        container = (
            soup.find("article")
            or soup.select_one(".article-content, .post-content, .entry-content, .article-body, [itemprop='articleBody']")
            or soup.find("main")
            or soup.body
        )

        nodes: List[Tuple[str, ...]] = []
        if container:
            # Find paragraphs, headers, blockquotes, figures
            for el in container.find_all(["p", "h2", "h3", "h4", "blockquote", "figure"]):
                if el.find_parent(["aside", "nav", "footer", "header"]):
                    continue
                if el.find_parent(["blockquote", "figure"]) and el.name in ["p", "h2", "h3", "h4"]:
                    continue

                txt = el.get_text(strip=True)
                if not txt and el.name != "figure":
                    continue

                tag = el.name
                if tag == "p":
                    cleaned = clean_inline_html(el)
                    if len(cleaned) > 20:
                        nodes.append(("p", cleaned))
                elif tag in ["h2", "h3", "h4"]:
                    cleaned = clean_inline_html(el)
                    if cleaned and cleaned != subtitle:
                        nodes.append(("header", tag, cleaned))
                elif tag == "blockquote":
                    cleaned = clean_inline_html(el)
                    if cleaned:
                        nodes.append(("blockquote", cleaned))
                elif tag == "figure":
                    img = el.find("img")
                    cap = el.find(["figcaption", "small"])
                    src = img.get("src", "") if img else ""
                    cap_text = clean_inline_html(cap) if cap else ""
                    if src or cap_text:
                        nodes.append(("figure", cap_text, src))

        return Article(
            title=title or "Untitled",
            subtitle=subtitle,
            author=author,
            bio="",
            date=date,
            source_url=source_url,
            lead_image=lead_image,
            lead_caption=lead_caption,
            nodes=nodes,
            site_name=site_name or self.site_display_name,
        )
