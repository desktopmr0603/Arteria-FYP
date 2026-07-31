import re

with open("/Users/manileshramlugun/Downloads/Arteria-FYP/lib/features/trends/presentation/pages/trends_screen.dart", "r") as f:
    text = f.read()

replacements = {
    # Theme primary / secondary
    "0xFF6366F1": "0xFF00CED1", # Indigo -> Primary
    "0xFF8B5CF6": "0xFF4C7F80", # Purple -> Secondary

    # SYS/DIA Colors
    "0xFFEF4444": "0xFFFFA54A", # Red (SYS/Error) -> Tertiary (Orange)
    "0xFF3B82F6": "0xFF00CED1", # Blue (DIA) -> Primary (Cyan)
    
    # Blood Pressure levels/indicators
    "0xFF10B981": "0xFF00CED1", # Green -> Primary
    "0xFFF59E0B": "0xFFFFA54A", # Amber -> Tertiary
    "0xFFF97316": "0xFF4C7F80", # Orange -> Secondary
    "0xFFDC2626": "0xFFFFA54A", # Red -> Tertiary
    
    # Dark Mode Backgrounds & Surfaces
    "0xFF0A0A0F": "0xFF090909", # Main bg dark
    "0xFF12121A": "0xFF121212", # Card inner dark
    "0xFF1A1A24": "0xFF1A1A1A", # Card outer dark
    "0xFF2D2D3A": "0xFF262626", # Buttons dark
}

for old, new in replacements.items():
    text = text.replace(old, new)

with open("/Users/manileshramlugun/Downloads/Arteria-FYP/lib/features/trends/presentation/pages/trends_screen.dart", "w") as f:
    f.write(text)

print("Colors updated successfully.")
