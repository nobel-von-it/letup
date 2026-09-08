"""
Site detector and parser registry.
Enables automatic detection of website sources without requiring explicit flags.
"""
import os
from typing import Dict, Type, Optional, List, Tuple
from urllib.parse import urlparse
from bs4 import BeautifulSoup

from .base import BaseParser
from .aeon import AeonParser
from .psyche import PsycheParser
from .quantamagazine import QuantaMagazineParser
from .theconversation import TheConversationParser
from .generic import GenericParser

# Registered parsers in priority order
_PARSER_CLASSES: List[Type[BaseParser]] = [
    AeonParser,
    PsycheParser,
    QuantaMagazineParser,
    TheConversationParser,
]

_PARSER_REGISTRY: Dict[str, Type[BaseParser]] = {
    cls.name.lower(): cls for cls in _PARSER_CLASSES
}
# Aliases for convenience
_PARSER_REGISTRY["quanta"] = QuantaMagazineParser
_PARSER_REGISTRY["conversation"] = TheConversationParser
_PARSER_REGISTRY["generic"] = GenericParser


def register_parser(cls: Type[BaseParser]) -> Type[BaseParser]:
    """Decorator to register a new parser class."""
    if cls not in _PARSER_CLASSES:
        _PARSER_CLASSES.append(cls)
    _PARSER_REGISTRY[cls.name.lower()] = cls
    return cls


def get_registered_parsers() -> Dict[str, Type[BaseParser]]:
    """Return dictionary of registered parsers."""
    return dict(_PARSER_REGISTRY)


def list_available_parsers() -> List[Dict[str, str]]:
    """Return list of available parsers with their names and domains."""
    res = []
    seen = set()
    for cls in _PARSER_CLASSES:
        if cls.name in seen:
            continue
        seen.add(cls.name)
        res.append({
            "name": cls.name,
            "display_name": cls.site_display_name,
            "domains": ", ".join(cls.domains) if cls.domains else "Any (fallback)",
        })
    res.append({
        "name": GenericParser.name,
        "display_name": GenericParser.site_display_name,
        "domains": "Any standard article website",
    })
    return res


def detect_parser(url_or_path: str, html: Optional[str] = None) -> BaseParser:
    """
    Automatically detects and instantiates the appropriate parser.
    
    1. Checks URL domain against registered parsers.
    2. If url_or_path is a local file or ambiguous, inspects HTML tags
       (canonical link, og:url, og:site_name, ld+json).
    3. Falls back to GenericParser.
    """
    # 1. URL Domain Matching
    if not os.path.exists(url_or_path):
        for parser_cls in _PARSER_CLASSES:
            if parser_cls.can_handle(url_or_path):
                return parser_cls()
    else:
        # It's a local file: read beginning to inspect metadata
        if html is None:
            try:
                with open(url_or_path, "r", encoding="utf-8", errors="replace") as f:
                    html = f.read(50000)
            except Exception:
                html = ""

    # 2. HTML Inspection (for local files or custom redirects)
    if html:
        soup = BeautifulSoup(html[:50000], "lxml")
        candidate_urls: List[str] = []

        canonical = soup.find("link", rel=lambda r: r and "canonical" in r)
        if canonical and canonical.get("href"):
            candidate_urls.append(canonical["href"])

        og_url = soup.find("meta", property="og:url")
        if og_url and og_url.get("content"):
            candidate_urls.append(og_url["content"])

        for cand_url in candidate_urls:
            for parser_cls in _PARSER_CLASSES:
                if parser_cls.can_handle(cand_url):
                    return parser_cls()

        # Check content markers in HTML
        for parser_cls in _PARSER_CLASSES:
            if parser_cls.can_handle(url_or_path, html=html):
                return parser_cls()

    # 3. Fallback to GenericParser
    return GenericParser()


def get_parser(name_or_auto: str = "auto", url_or_path: str = "") -> BaseParser:
    """
    Get parser instance either by explicit name or by automatic detection.
    """
    if not name_or_auto or name_or_auto.lower() in ["auto", "detect"]:
        return detect_parser(url_or_path)

    key = name_or_auto.lower()
    if key in _PARSER_REGISTRY:
        return _PARSER_REGISTRY[key]()

    # Check by domain substring
    for cls in _PARSER_CLASSES:
        if any(key in d for d in cls.domains) or key == cls.name:
            return cls()

    raise ValueError(
        f"Unknown parser '{name_or_auto}'. Available: {list(_PARSER_REGISTRY.keys())}"
    )
