"""Поиск без разницы языка — так же, как в приложении
(lib/services/search/search_matcher.dart): «adidas» = «Адидас», «найк» = «Nike»."""
import re

_CYRILLIC = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh",
    "з": "z", "и": "i", "й": "i", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o",
    "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h", "ц": "ts",
    "ч": "ch", "ш": "sh", "щ": "sh", "ъ": "", "ы": "i", "ь": "", "э": "e", "ю": "iu",
    "я": "ia", "ә": "a", "ғ": "g", "қ": "k", "ң": "n", "ө": "o", "ұ": "u", "ү": "u",
    "һ": "h", "і": "i",
}


def simplify(word: str) -> str:
    s = "".join(_CYRILLIC.get(ch, ch) for ch in word.lower())
    s = re.sub("[^a-z0-9]", "", s)
    for old, new in (("ph", "f"), ("ck", "k"), ("kh", "h"), ("x", "ks"), ("w", "v"),
                     ("y", "i"), ("ee", "i"), ("oo", "u")):
        s = s.replace(old, new)
    s = re.sub("c(?!h)", "k", s)
    return re.sub(r"(.)\1+", r"\1", s)


def consonants(simplified: str) -> str:
    return re.sub("[aeiou]", "", simplified)


def _words(text: str) -> list:
    return [w for w in re.split(r"[^a-zа-яёәғқңөұүһі0-9]+", text.lower()) if w]


def matches(query: str, texts) -> bool:
    plain = " ".join(t for t in texts if t).lower()
    words = [simplify(w) for w in _words(plain)]
    for raw in _words(query):
        if raw in plain:
            continue
        q = simplify(raw)
        qc = consonants(q)
        if not any((len(q) >= 3 and w.startswith(q)) or (len(qc) >= 2 and consonants(w) == qc)
                   for w in words):
            return False
    return True
