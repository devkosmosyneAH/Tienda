"""
GENERADOR DE ASSETS PREMIUM PARA INSTALADOR
Diseño inspirado en: VS Code, Discord, Notion, Linear
Estilo: Dark, Minimal, Elegant, Futuristic, Professional
"""

from PIL import Image, ImageDraw, ImageFont
import os

# ============================================================================
# COLORES PREMIUM
# ============================================================================
COLOR_BACKGROUND_DARK = "#111111"  # Fondo principal ultra oscuro
COLOR_SECONDARY_DARK = "#1E1E1E"  # Fondo secundario
COLOR_ORANGE_ACCENT = "#FF0000"  # Acento naranja premium
COLOR_TEXT_LIGHT = "#EAEAEA"  # Texto claro


def hex_to_rgb(hex_color):
    """Convierte color hex a RGB"""
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))


# ============================================================================
# CREAR SIDEBAR PREMIUM (164x314px)
# ============================================================================


def create_premium_sidebar():
    """Crea el sidebar vertical premium con branding oscuro y elegante"""

    # Dimensiones
    width, height = 164, 314

    # Crear imagen base con fondo oscuro
    img = Image.new("RGB", (width, height), hex_to_rgb(COLOR_BACKGROUND_DARK))
    draw = ImageDraw.Draw(img)

    # ========== FONDO DEGRADADO SUTIL ==========
    for y in range(height):
        # Degradado muy sutil de #111111 a #1E1E1E
        # De 17 (#111111) a 30 (#1E1E1E)
        intensity = int(17 + (y / height) * 13)
        color = (intensity, intensity, intensity)
        draw.line([(0, y), (width, y)], fill=color)

    # ========== ELEMENTOS GEOMÉTRICOS DECORATIVOS ==========
    # Líneas verticales sutiles a la izquierda
    draw.line(
        [(8, 40), (8, height - 40)], fill=hex_to_rgb(COLOR_SECONDARY_DARK), width=1
    )
    draw.line(
        [(12, 60), (12, height - 60)], fill=hex_to_rgb(COLOR_SECONDARY_DARK), width=1
    )

    # Línea de acento naranja sutil
    orange_rgb = hex_to_rgb(COLOR_ORANGE_ACCENT)
    draw.line([(4, height // 2 - 30), (4, height // 2 + 30)], fill=orange_rgb, width=2)

    # ========== LOGO REAL DE  SAAS ==========
    center_x = width // 2
    center_y = height // 2 - 20

    # Cargar logo original
    logo_path = "assets/image/logotienda.png"
    if os.path.exists(logo_path):
        try:
            logo = Image.open(logo_path)
            if logo.mode != "RGBA":
                logo = logo.convert("RGBA")

            # Redimensionar logo para el sidebar (80x80px)
            logo_size = 80
            logo_resized = logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)

            # Posicionar logo centrado
            logo_x = center_x - logo_size // 2
            logo_y = center_y - logo_size // 2

            # Pegar logo sobre el fondo (con transparencia)
            img.paste(logo_resized, (logo_x, logo_y), logo_resized)

        except Exception as e:
            print(f"⚠ Error al cargar logo para sidebar: {e}")
            # Fallback: crear logo genérico
            draw.ellipse(
                [center_x - 30, center_y - 30, center_x + 30, center_y + 30],
                fill=hex_to_rgb(COLOR_SECONDARY_DARK),
                outline=orange_rgb,
                width=2,
            )
    else:
        # Fallback si no existe el logo
        draw.ellipse(
            [center_x - 30, center_y - 30, center_x + 30, center_y + 30],
            fill=hex_to_rgb(COLOR_SECONDARY_DARK),
            outline=orange_rgb,
            width=2,
        )

    # ========== TEXTO "Tienda SAAS" ==========
    try:
        # Intentar usar fuente del sistema moderna
        try:
            font_title = ImageFont.truetype("segoeui.ttf", 14)
            font_subtitle = ImageFont.truetype("segoeui.ttf", 9)
        except:
            try:
                font_title = ImageFont.truetype("arial.ttf", 14)
                font_subtitle = ImageFont.truetype("arial.ttf", 9)
            except:
                font_title = ImageFont.load_default()
                font_subtitle = ImageFont.load_default()

        # Texto principal
        text_y = center_y + 50
        title_text = "Tienda"
        subtitle_text = "SAAS"

        # Calcular posición centrada para el título
        try:
            bbox = draw.textbbox((0, 0), title_text, font=font_title)
            text_width = bbox[2] - bbox[0]
        except:
            text_width = len(title_text) * 8

        draw.text(
            (center_x - text_width // 2, text_y),
            title_text,
            fill=hex_to_rgb(COLOR_TEXT_LIGHT),
            font=font_title,
        )

        # Subtítulo
        try:
            bbox = draw.textbbox((0, 0), subtitle_text, font=font_subtitle)
            text_width = bbox[2] - bbox[0]
        except:
            text_width = len(subtitle_text) * 6

        draw.text(
            (center_x - text_width // 2, text_y + 20),
            subtitle_text,
            fill=orange_rgb,
            font=font_subtitle,
        )

    except Exception as e:
        print(f"Advertencia al crear texto: {e}")

    # ========== DETALLES GEOMÉTRICOS INFERIORES ==========
    # Pequeños rectángulos decorativos
    for i in range(3):
        x = center_x - 20 + i * 20
        y = height - 30
        size = 3
        draw.rectangle(
            [x - size, y - size, x + size, y + size],
            fill=hex_to_rgb(COLOR_SECONDARY_DARK),
        )

    # Punto naranja central inferior
    draw.ellipse(
        [center_x - 2, height - 32, center_x + 2, height - 28], fill=orange_rgb
    )

    # Guardar
    output_path = "installer_assets/wizard_image.bmp"
    os.makedirs("installer_assets", exist_ok=True)
    img.save(output_path, "BMP")
    print(f"✓ Sidebar premium creado: {output_path}")
    return output_path


# ============================================================================
# CREAR LOGO PEQUEÑO (55x58px)
# ============================================================================


def create_premium_small_logo():
    """Crea el logo pequeño premium para el banner superior"""

    # Dimensiones
    width, height = 55, 58

    # Crear imagen con fondo oscuro
    img = Image.new("RGB", (width, height), hex_to_rgb(COLOR_BACKGROUND_DARK))
    draw = ImageDraw.Draw(img)

    # Centro
    center_x = width // 2
    center_y = height // 2

    # ========== LOGO REAL DE  SAAS ==========
    logo_path = "assets/image/logotienda.png"
    if os.path.exists(logo_path):
        try:
            logo = Image.open(logo_path)
            if logo.mode != "RGBA":
                logo = logo.convert("RGBA")

            # Redimensionar logo para el banner pequeño (50x50px)
            logo_size = 50
            logo_resized = logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)

            # Posicionar logo centrado
            logo_x = center_x - logo_size // 2
            logo_y = center_y - logo_size // 2

            # Pegar logo sobre el fondo (con transparencia)
            img.paste(logo_resized, (logo_x, logo_y), logo_resized)

        except Exception as e:
            print(f"⚠ Error al cargar logo para banner: {e}")
            # Fallback: crear logo genérico
            orange_rgb = hex_to_rgb(COLOR_ORANGE_ACCENT)
            draw.ellipse(
                [center_x - 18, center_y - 18, center_x + 18, center_y + 18],
                fill=hex_to_rgb(COLOR_SECONDARY_DARK),
                outline=orange_rgb,
                width=2,
            )
    else:
        # Fallback si no existe el logo
        orange_rgb = hex_to_rgb(COLOR_ORANGE_ACCENT)
        draw.ellipse(
            [center_x - 18, center_y - 18, center_x + 18, center_y + 18],
            fill=hex_to_rgb(COLOR_SECONDARY_DARK),
            outline=orange_rgb,
            width=2,
        )

    # Guardar
    output_path = "installer_assets/wizard_small_image.bmp"
    img.save(output_path, "BMP")
    print(f"✓ Logo pequeño premium creado: {output_path}")
    return output_path


# ============================================================================
# CREAR ICONO DE APLICACIÓN (256x256)
# ============================================================================


def create_app_icon():
    """Crea el icono principal de la aplicación usando el logo de  SAAS"""

    # Ruta del logo original
    logo_path = "assets/image/logotienda.png"

    # Verificar que existe el logo
    if not os.path.exists(logo_path):
        print(f"⚠ No se encontró {logo_path}, creando icono genérico...")
        # Fallback a logo genérico
        return create_app_icon_fallback()

    try:
        # Cargar el logo original
        logo = Image.open(logo_path)

        # Si tiene transparencia, mantenerla; si no, convertir a RGBA
        if logo.mode != "RGBA":
            logo = logo.convert("RGBA")

        # Crear icono en múltiples tamaños
        sizes = [256, 128, 64, 48, 32, 16]
        icons = []

        for size in sizes:
            # Redimensionar manteniendo calidad
            resized = logo.resize((size, size), Image.Resampling.LANCZOS)
            icons.append(resized)

        # Guardar como PNG (256x256)
        output_png = "installer_assets/app_icon.png"
        icons[0].save(output_png, "PNG")
        print(f"✓ Icono PNG creado: {output_png} (usando logotienda.png)")

        # Intentar crear ICO con múltiples resoluciones
        try:
            output_ico = "installer_assets/app_icon.ico"
            icons[0].save(
                output_ico,
                "ICO",
                sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)],
            )
            print(f"✓ Icono ICO creado: {output_ico} (multi-resolución)")
        except Exception as e:
            print(f"⚠ No se pudo crear ICO multi-resolución: {e}")
            # Intentar con solo una resolución
            try:
                icons[0].save(output_ico, format="ICO")
                print(f"✓ Icono ICO creado: {output_ico} (resolución única)")
            except Exception as e2:
                print(f"⚠ No se pudo crear ICO, usando PNG: {e2}")

        return output_png

    except Exception as e:
        print(f"⚠ Error al procesar {logo_path}: {e}")
        print("  Creando icono genérico como respaldo...")
        return create_app_icon_fallback()


def create_app_icon_fallback():
    """Crea un icono genérico si no se encuentra el logo"""

    width, height = 256, 256

    # Crear imagen con fondo transparente
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center_x = width // 2
    center_y = height // 2

    # Círculo con resplandor naranja
    orange_rgb = hex_to_rgb(COLOR_ORANGE_ACCENT)
    for radius in range(100, 85, -1):
        alpha = int(200 * (100 - radius) / 15)
        glow_color = orange_rgb + (alpha,)
        draw.ellipse(
            [
                center_x - radius,
                center_y - radius,
                center_x + radius,
                center_y + radius,
            ],
            fill=glow_color,
        )

    # Círculo principal oscuro
    dark_rgb = hex_to_rgb(COLOR_SECONDARY_DARK)
    draw.ellipse(
        [center_x - 85, center_y - 85, center_x + 85, center_y + 85],
        fill=dark_rgb + (255,),
    )

    # Borde naranja grueso
    draw.ellipse(
        [center_x - 85, center_y - 85, center_x + 85, center_y + 85],
        outline=orange_rgb + (255,),
        width=6,
    )

    # "G" grande estilizada
    draw.arc(
        [center_x - 50, center_y - 50, center_x + 50, center_y + 50],
        start=45,
        end=315,
        fill=orange_rgb + (255,),
        width=15,
    )
    draw.line(
        [(center_x + 5, center_y), (center_x + 50, center_y)],
        fill=orange_rgb + (255,),
        width=15,
    )

    # Guardar como PNG
    output_png = "installer_assets/app_icon.png"
    img.save(output_png, "PNG")
    print(f"✓ Icono PNG genérico creado: {output_png}")

    # Intentar convertir a ICO
    try:
        output_ico = "installer_assets/app_icon.ico"
        img.save(
            output_ico,
            "ICO",
            sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)],
        )
        print(f"✓ Icono ICO genérico creado: {output_ico}")
    except Exception as e:
        print(f"⚠ No se pudo crear ICO: {e}")

    return output_png


# ============================================================================
# MAIN
# ============================================================================
if __name__ == "__main__":
    print("=" * 70)
    print("  GENERADOR DE ASSETS PREMIUM - INSTALADOR Tienda SAAS")
    print("  Estilo: Dark, Modern, Elegant, Professional")
    print("=" * 70)
    print()

    try:
        # Crear todos los assets
        create_premium_sidebar()
        create_premium_small_logo()
        create_app_icon()

        print()
        print("=" * 70)
        print("  ✓ TODOS LOS ASSETS PREMIUM CREADOS EXITOSAMENTE")
        print("=" * 70)
        print()
        print("Assets generados:")
        print("  • installer_assets/wizard_image.bmp (164x314px)")
        print("  • installer_assets/wizard_small_image.bmp (55x58px)")
        print("  • installer_assets/app_icon.ico (256x256px)")
        print()
        print("Ahora puedes compilar el instalador premium con:")
        print("  build_installer_x64.bat")
        print()

    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback

        traceback.print_exc()
