#!/usr/bin/env python3
"""
Simple script to create basic app icons for Android
"""

import os
from PIL import Image, ImageDraw

def create_icon(size, filename):
    """Create a simple app icon"""
    # Create a new image with blue background
    img = Image.new('RGBA', (size, size), (25, 118, 210, 255))  # Material Blue
    draw = ImageDraw.Draw(img)
    
    # Draw a simple robot/AI icon
    center = size // 2
    
    # Head circle
    head_radius = size // 4
    draw.ellipse([center - head_radius, center - head_radius, 
                  center + head_radius, center + head_radius], 
                 fill=(255, 255, 255, 255))
    
    # Eyes
    eye_size = size // 12
    eye_y = center - size // 8
    draw.ellipse([center - size//6, eye_y, center - size//6 + eye_size, eye_y + eye_size], 
                 fill=(25, 118, 210, 255))
    draw.ellipse([center + size//6 - eye_size, eye_y, center + size//6, eye_y + eye_size], 
                 fill=(25, 118, 210, 255))
    
    # Save the image
    img.save(filename, 'PNG')
    print(f"Created {filename} ({size}x{size})")

# Create icons for different densities
sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192
}

for density, size in sizes.items():
    icon_dir = f'app/src/main/res/mipmap-{density}'
    os.makedirs(icon_dir, exist_ok=True)
    create_icon(size, f'{icon_dir}/ic_launcher.png')
    create_icon(size, f'{icon_dir}/ic_launcher_round.png')

print("All app icons created successfully!")