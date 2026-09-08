"""
Psyche Article & Guide Parser (psyche.co)
Specialized parser for Psyche (Aeon Media sister publication).
"""
from typing import List
from bs4 import BeautifulSoup

from .base import Article
from .aeon import AeonParser


class PsycheParser(AeonParser):
    name: str = "psyche"
    site_display_name: str = "Psyche"
    domains: List[str] = ["psyche.co"]

    def extract(self, soup: BeautifulSoup, source_url: str, raw_html: str) -> Article:
        # Re-use Aeon's robust extraction logic
        article = super().extract(soup, source_url, raw_html)
        article.site_name = self.site_display_name
        return article
