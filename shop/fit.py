"""
TryOn: отыру логикасы (shop/fit.py) — docs/fit-logic.md бойынша.

айырма = киім өлшемі − дене өлшемі
айырма < tight_below  -> 'tight' (қысады)
айырма > loose_above  -> 'loose' (бос)
әйтпесе               -> 'fit'   (дәл отырады)
Шектер fit_rules кестесінен оқылады, кодта жазылмайды.
"""
from decimal import Decimal

from .models import FitRule

SIZE_ORDER = ["XS", "S", "M", "L", "XL", "XXL"]
THIGH_K = Decimal("0.56")   # сан ≈ жамбас × 0,56

# аймақ -> (ProductSize өрісі, дене өлшемін алатын функция)
ZONES = {
    "chest": ("chest_cm", lambda b: b.chest_cm),
    "hem":   ("hem_cm",   lambda b: b.hip_cm),
    "waist": ("waist_cm", lambda b: b.waist_cm),
    "hip":   ("hip_cm",   lambda b: b.hip_cm),
    "thigh": ("thigh_cm", lambda b: (b.hip_cm * THIGH_K).quantize(Decimal("0.1"))),  # view-дегі ROUND(..., 1)
}


def verdict(diff, rule):
    if diff < rule.tight_below:
        return "tight"
    if diff > rule.loose_above:
        return "loose"
    return "fit"


def check_size(product_size, body, rules):
    """Бір өлшем бойынша аймақтар: [{'zone', 'body', 'garment', 'diff', 'verdict'}]"""
    result = []
    for rule in rules:
        field, body_value = ZONES[rule.zone]
        garment = getattr(product_size, field)
        if garment is None:
            continue
        b = body_value(body)
        diff = garment - b
        result.append({"zone": rule.zone, "body": b, "garment": garment,
                       "diff": diff, "verdict": verdict(diff, rule)})
    return result


def recommend_size(product, body):
    """Ешбір аймағы 'tight' емес және қоймада бар ең кіші өлшем (жоқ болса None)."""
    rules = list(FitRule.objects.filter(garment_type=product.garment_type))
    sizes = sorted(product.sizes.filter(stock_qty__gt=0),
                   key=lambda s: SIZE_ORDER.index(s.size_label)
                   if s.size_label in SIZE_ORDER else 99)
    for s in sizes:
        zones = check_size(s, body, rules)
        if zones and all(z["verdict"] != "tight" for z in zones):
            return s
    return None
