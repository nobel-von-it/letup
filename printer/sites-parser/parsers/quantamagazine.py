"""
Quanta Magazine Parser (quantamagazine.org)
Extracts science, physics, mathematics, and biology essays and in-depth articles.
"""
import re
from typing import List, Tuple
from bs4 import BeautifulSoup

from .base import BaseParser, Article, clean_inline_html, clean_title


class QuantaMagazineParser(BaseParser):
    name: str = "quantamagazine"
    site_display_name: str = "Quanta Magazine"
    domains: List[str] = ["quantamagazine.org"]

    def extract(self, soup: BeautifulSoup, source_url: str, raw_html: str) -> Article:
        # Title
        title = ""
        h1 = soup.find("h1")
        if h1:
            title = clean_inline_html(h1)
        else:
            og_title = soup.find("meta", property="og:title")
            if og_title and og_title.get("content"):
                title = og_title["content"].split("|")[0].strip()

        # Subtitle / Deck
        subtitle = ""
        og_desc = soup.find("meta", property="og:description")
        if og_desc and og_desc.get("content"):
            subtitle = og_desc["content"].strip()
        if not subtitle:
            deck_el = soup.select_one(".post__subdeck, .post__deck, .hero__deck")
            if deck_el:
                subtitle = clean_inline_html(deck_el)

        # Author
        author = ""
        author_links = soup.select(".post__byline a[href*='/authors/'], .byline a[href*='/authors/']")
        if author_links:
            # First author link that is not "Contributing Writer"
            for a in author_links:
                txt = a.get_text(strip=True)
                txt = re.sub(r"^(By\s*|Contributing\s*Writer)", "", txt, flags=re.IGNORECASE).strip()
                if txt and "writer" not in txt.lower():
                    author = txt
                    break
        if not author:
            meta_auth = soup.find("meta", attrs={"name": "author"})
            if meta_auth and meta_auth.get("content"):
                author = meta_auth["content"].strip()

        # Date
        date = ""
        # Check URL pattern YYYYMMDD at end (e.g. -20260902/)
        url_match = re.search(r"-(\d{4})(\d{2})(\d{2})/?$", source_url)
        if url_match:
            date = f"{url_match.group(1)}-{url_match.group(2)}-{url_match.group(3)}"
        if not date:
            date_meta = soup.find("meta", property="article:published_time")
            if date_meta and date_meta.get("content"):
                date = date_meta["content"].split("T")[0]
        if not date:
            date_el = soup.select_one(".post__title__author-date, time")
            if date_el:
                # Find date like 'September 2, 2026'
                m = re.search(r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},\s+\d{4}", date_el.text)
                if m:
                    date = m.group(0)

        # Author Bio
        bio = ""
        for p in soup.select(".post__author__description, .author-bio, [class*='author__bio']"):
            bio_text = clean_inline_html(p)
            if len(bio_text) > 30:
                bio = bio_text
                break

        # Lead image & caption
        lead_image = None
        lead_caption = ""
        og_img = soup.find("meta", property="og:image")
        if og_img and og_img.get("content"):
            lead_image = og_img["content"]

        header_attr = soup.select_one("header .attribution, .hero__attribution, .post__title__wrapper .attribution")
        if header_attr:
            lead_caption = clean_inline_html(header_attr)

        # Body Extraction
        nodes: List[Tuple[str, ...]] = []
        main = soup.find("main") or soup.find("article") or soup.body

        if main:
            content_sections = main.select("section.outer--content, div.post__content")
            if not content_sections:
                content_sections = [main]

            seen_paras = set()

            for section in content_sections:
                s_cls = " ".join(section.get("class", []))
                # Skip navigation/newsletter/comment/footer sections
                if any(bad in s_cls for bad in ["newsletter", "comments", "post__category", "footer", "mega__"]):
                    continue

                for el in section.find_all(["p", "h2", "h3", "h4", "blockquote", "figure"], recursive=True):
                    # Skip if inside sidebar, aside, nav, author box or newsletter
                    if el.find_parent(["aside", "nav", ".sidebar__newsletter", ".mega__notice"]):
                        continue

                    # Skip if inside another element we are already iterating over
                    if el.find_parent(["blockquote", "figure"]) and el.name in ["p", "h2", "h3", "h4"]:
                        continue

                    txt = el.get_text(strip=True)

                    # Filter out newsletter prompts and social notices
                    if "Get the latest news" in txt or "Get Quanta Magazine delivered" in txt:
                        continue
                    if "An editorially independent publication supported" in txt:
                        continue
                    if txt == "Next article" or txt == "Saved Articles":
                        continue
                    if date and txt == date:
                        continue
                    if author and txt.strip() == author:
                        continue

                    tag = el.name

                    if tag == "p":
                        cleaned = clean_inline_html(el)
                        # De-duplicate identical text
                        if cleaned and cleaned not in seen_paras:
                            seen_paras.add(cleaned)
                            nodes.append(("p", cleaned))

                    elif tag in ["h2", "h3", "h4"]:
                        cleaned = clean_title(el)
                        if cleaned and cleaned.lower() not in ["next article", "related content", "comments"]:
                            if cleaned not in seen_paras:
                                seen_paras.add(cleaned)
                                nodes.append(("header", tag, cleaned))

                    elif tag == "blockquote":
                        cleaned = clean_inline_html(el)
                        if cleaned:
                            nodes.append(("blockquote", cleaned))

                    elif tag == "figure":
                        img = el.find("img")
                        cap = el.find(["figcaption", "div.caption", "small"])
                        src = img.get("src", "") if img else ""
                        cap_text = clean_inline_html(cap) if cap else ""
                        if src or cap_text:
                            nodes.append(("figure", cap_text, src))

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
