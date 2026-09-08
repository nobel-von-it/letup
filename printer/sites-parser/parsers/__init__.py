"""
Article Parsers Package
Multi-site article extractor and detector.
"""
from .base import Article, BaseParser, clean_inline_html, format_markdown
from .detector import (
    detect_parser,
    get_parser,
    register_parser,
    list_available_parsers,
    get_registered_parsers,
)
from .aeon import AeonParser
from .psyche import PsycheParser
from .quantamagazine import QuantaMagazineParser
from .theconversation import TheConversationParser
from .generic import GenericParser

__all__ = [
    "Article",
    "BaseParser",
    "clean_inline_html",
    "format_markdown",
    "detect_parser",
    "get_parser",
    "register_parser",
    "list_available_parsers",
    "get_registered_parsers",
    "AeonParser",
    "PsycheParser",
    "QuantaMagazineParser",
    "TheConversationParser",
    "GenericParser",
]
