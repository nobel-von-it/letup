"""
The Conversation Parser (theconversation.com)
Extracts academic, research-backed news, analysis, and essays.
"""
import re
from typing import List, Tuple
from bs4 import BeautifulSoup

from .base import BaseParser, Article, clean_inline_html


class TheConversationParser(BaseParser):
    name: str = "theconversation"
    site_display_name: str = "The Conversation"
    domains: List[str] = ["theconversation.com"]

    def extract(self, soup: BeautifulSoup, source_url: str, raw_html: str) -> Article:
        # Title
        title = ""
        h1 = soup.find("h1")
        if h1:
            title = clean_inline_html(h1)
        else:
            og_title = soup.find("meta", property="og:title")
            if og_title and og_title.get("content"):
                title = og_title["content"].strip()

        # Subtitle
        subtitle = ""
        og_desc = soup.find("meta", property="og:description")
        if og_desc and og_desc.get("content"):
            subtitle = og_desc["content"].strip()
        elif soup.find("p", class_="lead"):
            subtitle = clean_inline_html(soup.find("p", class_="lead"))

        # Author(s)
        authors: List[str] = []
        for meta_a in soup.find_all("meta", attrs={"name": "author"}):
            c = meta_a.get("content", "").strip()
            if c and c not in authors:
                authors.append(c)

        if not authors:
            for a_tag in soup.select(".author-name a, [itemprop='author']"):
                t = a_tag.get_text(strip=True)
                if t and t not in authors:
                    authors.append(t)

        author = ", ".join(authors)

        # Date
        date = ""
        pubdate_meta = soup.find("meta", attrs={"name": "pubdate"})
        if pubdate_meta and pubdate_meta.get("content"):
            # Format: YYYYMMDD
            raw_pub = pubdate_meta["content"].strip()
            if len(raw_pub) == 8 and raw_pub.isdigit():
                date = f"{raw_pub[:4]}-{raw_pub[4:6]}-{raw_pub[6:]}"
            else:
                date = raw_pub

        if not date:
            time_meta = soup.find("meta", property="article:published_time")
            if time_meta and time_meta.get("content"):
                date = time_meta["content"].split("T")[0]

        if not date:
            time_tag = soup.find("time")
            if time_tag:
                date = time_tag.get_text(strip=True)

        # Author Bio / Affiliations
        bio_parts = []
        for bio_el in soup.select(".author-title, .author-bio, [class*='author'] .affiliations, .author-profile"):
            t = clean_inline_html(bio_el)
            if t and t not in bio_parts:
                bio_parts.append(t)
        bio = "\n".join(bio_parts)

        # Lead image
        lead_image = None
        lead_caption = ""
        lead_fig = soup.select_one("figure.lead-image, .figure-lead")
        if lead_fig:
            img = lead_fig.find("img")
            if img:
                lead_image = img.get("src")
            cap = lead_fig.find("figcaption")
            if cap:
                lead_caption = clean_inline_html(cap)

        if not lead_image:
            og_img = soup.find("meta", property="og:image")
            if og_img and og_img.get("content"):
                lead_image = og_img["content"]

        # Body extraction
        nodes: List[Tuple[str, ...]] = []
        content = soup.select_one(".content-body, [itemprop='articleBody'], .entry-content")
        if not content:
            content = soup.find("article") or soup.find("main")

        if content:
            for child in content.children:
                if not hasattr(child, "name") or not child.name:
                    continue

                tag = child.name
                cls = child.get("class", [])
                cls_str = " ".join(cls) if cls else ""

                # Skip lead figure inside content if already captured
                if "lead-image" in cls_str:
                    continue

                # Skip donation, newsletter, republish prompts
                txt = child.get_text(strip=True)
                if not txt:
                    continue
                if any(k in txt for k in ["Sign up for our newsletter", "Republish this article", "Donate now"]):
                    continue

                if tag == "p":
                    # Check for tracking pixel / counter image
                    if child.find("img") and "counter.theconversation.com" in str(child):
                        continue
                    p_text = clean_inline_html(child)
                    if p_text:
                        nodes.append(("p", p_text))

                elif tag == "blockquote":
                    q_text = clean_inline_html(child)
                    if q_text:
                        nodes.append(("blockquote", q_text))

                elif tag == "figure":
                    img = child.find("img")
                    cap = child.find("figcaption")
                    cap_text = clean_inline_html(cap) if cap else ""
                    src = img.get("src", "") if img else ""
                    if src or cap_text:
                        nodes.append(("figure", cap_text, src))

                elif tag in ["h2", "h3", "h4"]:
                    h_text = clean_inline_html(child)
                    if h_text:
                        nodes.append(("header", tag, h_text))

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
