"""
Base classes, data models, and utility functions for article parsers.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Tuple, Any, Dict
import os
import re
import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse


@dataclass
class Article:
    """Standardized article data representation."""
    title: str
    subtitle: str = ""
    author: str = ""
    bio: str = ""
    date: str = ""
    source_url: str = ""
    lead_image: Optional[str] = None
    lead_caption: str = ""
    nodes: List[Tuple[str, ...]] = field(default_factory=list)
    site_name: str = ""
    language: str = "en-US"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dict for backward compatibility."""
        return asdict(self)

    def __getitem__(self, key: str) -> Any:
        """Dict-like access for backward compatibility."""
        return getattr(self, key)

    def get(self, key: str, default: Any = None) -> Any:
        return getattr(self, key, default)


def clean_inline_html(element: Any) -> str:
    """
    Cleanly converts inline elements (links, em, strong, code) to Markdown
    with proper spacing and punctuation handling.
    """
    if not element:
        return ""

    if not hasattr(element, "find_all"):
        text = str(element)
    else:
        # Clone or process element
        # Replace <a> with [text](href)
        for a in element.find_all("a"):
            href = a.get("href", "").strip()
            text = a.get_text().strip()
            if href.startswith("http") and text:
                a.replace_with(f" [{text}]({href}) ")
            elif text:
                a.replace_with(f" {text} ")
            else:
                a.decompose()

        for em in element.find_all(["em", "i"]):
            em_text = em.get_text().strip()
            if em_text:
                em.replace_with(f" *{em_text}* ")
            else:
                em.decompose()

        for strong in element.find_all(["strong", "b"]):
            strong_text = strong.get_text().strip()
            if strong_text:
                strong.replace_with(f" **{strong_text}** ")
            else:
                strong.decompose()

        for code in element.find_all("code"):
            code_text = code.get_text().strip()
            if code_text:
                code.replace_with(f" `{code_text}` ")
            else:
                code.decompose()

        text = element.get_text()

    # Normalize whitespaces
    text = re.sub(r'[ \t\r\f\v]+', ' ', text)
    # Fix punctuation spacing: "word , " -> "word, "
    text = re.sub(r'\s+([,.:;?!])', r'\1', text)
    # Fix parentheses / quotes spacing
    text = re.sub(r'\(\s+', '(', text)
    text = re.sub(r'\s+\)', ')', text)
    text = re.sub(r'([‘“])\s+', r'\1', text)
    text = re.sub(r'\s+([’”])', r'\1', text)

    # Fix spaces inside bold / italics formatting:
    # " * word * " -> " *word* "
    text = re.sub(r'\*\s+([^*]+?)\s+\*', r' *\1* ', text)
    text = re.sub(r'\*\*\s+([^*]+?)\s+\*\*', r' **\1** ', text)

    # Avoid redundant asterisks **** -> **
    text = re.sub(r'\*{4,}', '**', text)

    # Clean multiple spaces
    text = re.sub(r'[ \t]+', ' ', text)
    return text.strip()


def clean_title(element_or_text: Any) -> str:
    """Cleans a title string or HTML tag, stripping unwanted asterisks/formatting."""
    if not element_or_text:
        return ""
    if hasattr(element_or_text, "get_text"):
        text = element_or_text.get_text()
    else:
        text = str(element_or_text)
    # Strip asterisks, backticks, underscores that may wrap titles
    text = re.sub(r'[*_`]', '', text)
    # Normalize whitespaces
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def format_markdown(article: Article, chapter_num: Optional[int] = None) -> str:
    """Formats an Article into clean Markdown suitable for Pandoc, Typst, Booker."""
    lines = []

    # Frontmatter
    lines.append("---")
    safe_title = article.title.replace('"', '\\"')
    lines.append(f'title: "{safe_title}"')
    if article.author:
        safe_author = article.author.replace('"', '\\"')
        lines.append(f'author: "{safe_author}"')
    if article.date:
        lines.append(f'date: "{article.date}"')
    lines.append(f'lang: "{article.language}"')
    lines.append("---")
    lines.append("")

    # Main Title (with optional chapter number for booker_filter.lua)
    if chapter_num is not None:
        lines.append(f'# {chapter_num}. {article.title}')
    else:
        lines.append(f'# {article.title}')
    lines.append("")

    # Subtitle / Deck
    if article.subtitle:
        lines.append(f'> **{article.subtitle}**')
        lines.append("")

    # Byline
    byline_parts = []
    if article.author:
        byline_parts.append(f"By **{article.author}**")
    if article.date:
        byline_parts.append(article.date)
    if article.site_name:
        byline_parts.append(article.site_name)
    if byline_parts:
        lines.append(f"*{' | '.join(byline_parts)}*")
        lines.append("")

    lines.append("---")
    lines.append("")

    # Lead illustration if present
    if article.lead_caption:
        lines.append(f"*Illustration: {article.lead_caption}*")
        lines.append("")
    elif article.lead_image:
        lines.append(f"*[Lead Image: {article.lead_image}]*")
        lines.append("")

    # Body nodes
    for node in article.nodes:
        n_type = node[0]
        if n_type == "p":
            lines.append(node[1])
            lines.append("")
        elif n_type == "blockquote":
            lines.append(f"> {node[1]}")
            lines.append("")
        elif n_type == "figure":
            cap_text = node[1] if len(node) > 1 else ""
            src = node[2] if len(node) > 2 else ""
            if cap_text:
                lines.append(f"*[Image: {cap_text}]*")
            elif src:
                lines.append(f"*[Image: {src}]*")
            lines.append("")
        elif n_type == "header":
            tag = node[1]
            h_text = node[2]
            level = 2 if tag == "h2" else (3 if tag == "h3" else 4)
            lines.append(f"{'#' * level} {h_text}")
            lines.append("")

    # Author Bio at the end
    if article.bio:
        lines.append("---")
        lines.append("")
        lines.append(f"**About the Author:** {article.bio}")
        lines.append("")

    return "\n".join(lines)


class BaseParser(ABC):
    """Abstract Base Class for site-specific article extractors."""
    name: str = "base"
    site_display_name: str = "Base"
    domains: List[str] = []

    def __init__(self, session: Optional[requests.Session] = None):
        self.session = session or requests.Session()
        self.session.headers.update({
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9,ru;q=0.8",
        })

    @classmethod
    def can_handle(cls, url: str, html: str = "") -> bool:
        """Determines whether this parser can handle the given URL or HTML content."""
        if url:
            parsed = urlparse(url)
            host = parsed.netloc.lower()
            if ":" in host:
                host = host.split(":")[0]
            for domain in cls.domains:
                domain_lower = domain.lower()
                if host == domain_lower or host.endswith("." + domain_lower):
                    return True
        if html:
            for domain in cls.domains:
                if domain.lower() in html[:5000].lower():
                    return True
        return False

    def fetch(self, url_or_path: str) -> Tuple[str, str]:
        """Fetches HTML content from URL or reads local file. Returns (html, source_url)."""
        if os.path.exists(url_or_path):
            with open(url_or_path, "r", encoding="utf-8", errors="replace") as f:
                html = f.read()
            return html, "local_file"
        else:
            res = self.session.get(url_or_path, timeout=25)
            res.raise_for_status()
            return res.text, url_or_path

    def parse(self, url_or_path: str) -> Article:
        """Fetch and extract article data."""
        html, source_url = self.fetch(url_or_path)
        soup = BeautifulSoup(html, "lxml")
        article = self.extract(soup, source_url=source_url, raw_html=html)
        if not article.site_name and self.site_display_name:
            article.site_name = self.site_display_name
        if not article.source_url:
            article.source_url = source_url
        article.title = clean_title(article.title)
        return article

    @abstractmethod
    def extract(self, soup: BeautifulSoup, source_url: str, raw_html: str) -> Article:
        """Extract article data from BeautifulSoup."""
        pass
