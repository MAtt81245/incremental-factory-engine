---
name: blender-pixel-art
 description: Plan and automate a safe Blender-to-pixel-art workflow for game assets, sprites, renders, and Roblox imports. Use blockouts first, preserve files, and recommend a pixel-art editor for final cleanup.
---

# Blender Pixel Art

## Goal

Create repeatable, readable game art rather than one-off unpredictable renders.

## Before creating anything

Ask for or infer:

- Target game and engine.
- Sprite or render resolution.
- Camera angle.
- Style and palette.
- Whether the asset is a prop, character, environment, or animation.
- Required output formats.

If the request is broad, make a small blockout first.

## Default pipeline

1. Create a new collection or scene.
2. Build a low-detail blockout.
3. Use an orthographic camera.
4. Use simple, consistent lights and materials.
5. Render a small transparent PNG preview.
6. Check silhouette and readability at final size.
7. Improve geometry only where it affects the silhouette.
8. Export PNGs, sprite sheets, or FBX as requested.
9. Tell the user what was created and where it was saved.

## Pixel-art rules

- Prefer readable silhouettes over tiny detail.
- Keep colors limited and intentional.
- Avoid blurry scaling.
- Use nearest/point filtering for pixel textures.
- Do not rely on anti-aliasing to hide bad geometry.
- Recommend Aseprite or LibreSprite for final pixel cleanup and animation.

## File safety

- Never overwrite the original without permission.
- Save generated work in a new folder.
- Use predictable names.
- Preserve source `.blend` files.
- Do not execute downloaded scripts without inspection.

## MCP discipline

- Use one Blender MCP server at a time.
- Start with a harmless test scene.
- Do not modify unrelated objects.
- If MCP is unavailable, generate a standalone `bpy` script instead.

## Roblox export checks

Before export, check:

- Scale and orientation.
- Object names.
- Origin/pivot placement.
- Material count.
- Separate animated parts.
- Texture paths.
- Polygon and texture budget.
