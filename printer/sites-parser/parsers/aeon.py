"""
Aeon Essay Parser (aeon.co)
Extracts clean, publication-ready Markdown from Aeon.co essays.
"""
import re
import json
from typing import List, Tuple
from bs4 import BeautifulSoup

from .base import BaseParser, Article, clean_inline_html


class AeonParser(BaseParser):
    name: str = "aeon"
    site_display_name: str = "Aeon"
    domains: List[str] = ["aeon.co"]

    def extract(self, soup: BeautifulSoup, source_url: str, raw_html: str) -> Article:
        # 1. Metadata from JSON-LD
        article_meta = {}
        for script in soup.find_all("script", type="application/ld+json"):
            try:
                data = json.loads(script.string)
                if isinstance(data, dict) and data.get("@type") == "Article":
                    article_meta = data
                    break
            except Exception:
                pass

        # Title
        title = ""
        h1 = soup.find("h1")
        if h1:
            title = clean_inline_html(h1)
        elif article_meta.get("headline"):
            title = article_meta["headline"].strip()
        else:
            title_tag = soup.find("title")
            title = title_tag.get_text().split("|")[0].strip() if title_tag else "Untitled"

        # Subtitle
        subtitle = ""
        if h1:
            next_h2 = h1.find_next_sibling("h2")
            if next_h2:
                subtitle = clean_inline_html(next_h2)
        if not subtitle and article_meta.get("description"):
            subtitle = article_meta["description"].strip()

        # Author
        author = ""
        if article_meta.get("author"):
            authors = article_meta["author"]
            if isinstance(authors, list) and len(authors) > 0:
                author = authors[0].get("name", "").strip()
            elif isinstance(authors, dict):
                author = authors.get("name", "").strip()

        if not author:
            byline_match = re.search(r"by\s+<!--\s*-->([^<\n\r]+)", raw_html) or re.search(
                r"by\s+([A-Z][a-zA-Z\.\s]+?)(?: |<|\+)", raw_html
            )
            if byline_match:
                author = byline_match.group(1).strip()

        # Author bio
        bio = ""
        bio_candidates = soup.find_all(
            lambda e: e.name == "p"
            and any(
                k in e.text
                for k in ["is a writer", "is professor", "is an author", "lives in", "author of"]
            )
        )
        for bc in bio_candidates:
            t = clean_inline_html(bc)
            if 30 < len(t) < 500:
                if not t.startswith(author):
                    bio = f"{author} {t}".strip()
                else:
                    bio = t
                break

        # Date
        date = article_meta.get("datePublished", "")
        if date:
            date = date.split("T")[0]

        # Lead Image & caption
        lead_image = None
        lead_caption = ""
        header_img = soup.find("img", alt=True)
        if header_img and (
            "width" in header_img.get("src", "")
            or "images.aeonmedia.co" in header_img.get("src", "")
        ):
            lead_image = header_img.get("src")
            cap_el = soup.find(
                lambda e: e.name in ["small", "figcaption"]
                and (
                    "Courtesy" in e.text
                    or "quilt by" in e.text
                    or "photo" in e.text.lower()
                    or "painting by" in e.text
                )
            )
            if cap_el:
                lead_caption = clean_inline_html(cap_el)

        # 2. Main Article Body
        content_container = (
            soup.find(class_="has-dropcap")
            or soup.find("div", class_="article-content")
            or soup.find("main")
            or soup.body
        )

        nodes: List[Tuple[str, ...]] = []
        current_quote: List[str] = []

        def flush_quote():
            nonlocal current_quote
            if current_quote:
                all_short = all(len(l) < 80 for l in current_quote)
                if all_short and len(current_quote) > 1:
                    nodes.append(("blockquote", "  \n> ".join(current_quote)))
                else:
                    nodes.append(("blockquote", " ".join(current_quote)))
                current_quote = []

        if content_container:
            for child in content_container.children:
                if not hasattr(child, "name") or not child.name:
                    continue

                tag = child.name
                cls = child.get("class", [])
                cls_str = " ".join(cls) if cls else ""

                if tag != "blockquote" and current_quote:
                    flush_quote()

                # Skip pullquotes
                if "pullquote" in cls_str:
                    continue

                # Skip audio player and social sharing buttons
                txt = child.get_text(strip=True)
                if not txt:
                    continue
                if "Listen to this essay" in txt or "minute listen" in txt:
                    continue
                if "SYNDICATE THIS ESSAY" in txt or "Edited by" in txt:
                    continue

                if tag == "p":
                    if (
                        child.find("em")
                        and any(k in txt for k in ["Courtesy", "painting by", "quilt by"])
                        and len(txt) < 250
                    ):
                        if nodes and nodes[-1][0] == "figure":
                            continue

                    p_text = clean_inline_html(child)
                    if p_text:
                        nodes.append(("p", p_text))

                elif tag == "blockquote":
                    q_text = clean_inline_html(child)
                    if q_text:
                        current_quote.append(q_text)

                elif tag == "figure":
                    img = child.find("img")
                    cap = child.find("figcaption") or child.find("small")
                    cap_text = clean_inline_html(cap) if cap else ""
                    src = img.get("src", "") if img else ""
                    nodes.append(("figure", cap_text, src))

                elif tag in ["h2", "h3", "h4"]:
                    h_text = clean_inline_html(child)
                    if h_text and h_text != subtitle:
                        nodes.append(("header", tag, h_text))

        if current_quote:
            flush_quote()

        return Article(
            title=title,
            subtitle=subtitle,
            author=author,
            bio=bio,
            date=date,
            source_url=source_url,
            lead_image=lead_image,
            lead_caption=lead_caption,
            nodes=nodes,
            site_name=self.site_display_name,
        )
