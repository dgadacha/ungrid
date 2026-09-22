"""Fabrique les icônes de lancement à partir de design/icon.png.

    python3 design/make_icons.py && dart run flutter_launcher_icons

iOS veut une image pleine, sans transparence : le système applique son propre
masque arrondi. Android masque lui aussi le premier plan, et de façon
imprévisible selon le lanceur : on réduit donc le motif dans la zone sûre, et
on prolonge le fond jusqu'aux bords en étirant ses pixels, pour qu'aucun
raccord n'apparaisse quelle que soit la découpe.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
SIZE = 1024

# Part du canvas occupée par le motif sur Android. Les lanceurs peuvent rogner
# jusqu'à un tiers de l'image.
SAFE_RATIO = 0.74


def main() -> None:
    source = Image.open(ROOT / 'icon.png').convert('RGBA')
    square = min(source.size)
    left = (source.width - square) // 2
    top = (source.height - square) // 2
    icon = source.crop((left, top, left + square, top + square))

    flat = Image.new('RGB', icon.size, (255, 255, 255))
    flat.paste(icon, mask=icon.split()[3])
    flat.resize((SIZE, SIZE), Image.LANCZOS).save(ROOT / 'icon_ios.png')

    inner = int(SIZE * SAFE_RATIO)
    margin = (SIZE - inner) // 2
    scaled = flat.resize((inner, inner), Image.LANCZOS)

    foreground = Image.new('RGB', (SIZE, SIZE))
    foreground.paste(scaled, (margin, margin))
    _extend_edges(foreground, margin, inner)
    foreground.save(ROOT / 'icon_android_foreground.png')

    print('icônes écrites dans', ROOT)


def _extend_edges(image: Image.Image, margin: int, inner: int) -> None:
    """Prolonge les bords du motif jusqu'aux bords du canvas."""
    right = margin + inner
    top_band = image.crop((margin, margin, right, margin + 1))
    bottom_band = image.crop((margin, right - 1, right, right))
    image.paste(top_band.resize((inner, margin)), (margin, 0))
    image.paste(bottom_band.resize((inner, image.height - right)), (margin, right))

    left_band = image.crop((margin, 0, margin + 1, image.height))
    right_band = image.crop((right - 1, 0, right, image.height))
    image.paste(left_band.resize((margin, image.height)), (0, 0))
    image.paste(right_band.resize((image.width - right, image.height)), (right, 0))


if __name__ == '__main__':
    main()
