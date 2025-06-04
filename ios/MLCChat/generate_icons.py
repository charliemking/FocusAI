from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size, output_path):
    # Create a new image with a white background
    image = Image.new('RGB', (size, size), 'white')
    draw = ImageDraw.Draw(image)
    
    # Draw a gradient background
    for y in range(size):
        for x in range(size):
            r = int(255 * (1 - y/size))
            g = int(200 * (1 - x/size))
            b = 255
            draw.point((x, y), fill=(r, g, b))
    
    # Draw the main circle
    circle_size = int(size * 0.8)
    circle_pos = (size - circle_size) // 2
    draw.ellipse([circle_pos, circle_pos, circle_pos + circle_size, circle_pos + circle_size], 
                 fill='white', outline='white')
    
    # Draw the "F" letter
    if size >= 60:  # Only draw text for larger icons
        try:
            font_size = int(size * 0.5)
            # Try different system font paths
            font_paths = [
                "/System/Library/Fonts/Helvetica.ttc",
                "/System/Library/Fonts/Arial.ttf",
                "/Library/Fonts/Arial Bold.ttf",
                "/System/Library/Fonts/SFPro-Bold.ttf"
            ]
            
            font = None
            for font_path in font_paths:
                try:
                    if os.path.exists(font_path):
                        font = ImageFont.truetype(font_path, font_size)
                        break
                except:
                    continue
            
            if font is None:
                # Fallback to default font
                font = ImageFont.load_default()
                font_size = min(size // 2, 24)  # Limit size for default font
            
            text = "F"
            text_bbox = draw.textbbox((0, 0), text, font=font)
            text_width = text_bbox[2] - text_bbox[0]
            text_height = text_bbox[3] - text_bbox[1]
            text_x = (size - text_width) // 2
            text_y = (size - text_height) // 2
            draw.text((text_x, text_y), text, fill='#007AFF', font=font)
        except Exception as e:
            print(f"Could not draw text: {e}")
    
    # Save the image
    image.save(output_path, 'PNG')

def main():
    sizes = {
        "icon_40.png": 40,
        "icon_60.png": 60,
        "icon_58.png": 58,
        "icon_87.png": 87,
        "icon_80.png": 80,
        "icon_120.png": 120,
        "icon_180.png": 180,
        "icon_1024.png": 1024
    }
    
    output_dir = "MLCChat/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)
    
    for filename, size in sizes.items():
        output_path = os.path.join(output_dir, filename)
        create_icon(size, output_path)
        print(f"Generated {filename}")

if __name__ == "__main__":
    main() 