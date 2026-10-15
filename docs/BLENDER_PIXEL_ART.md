# Blender, Pixel Art, and AI Workflow

## Recommendation

Use Claude Code connected to Blender only if you want automation and repeatability. Do not expect an MCP server to replace an artist or automatically produce finished-quality art.

Recommended pipeline:

```text
Claude Code → plans and automates Blender with Python/MCP
Blender → creates models, scenes, cameras, lights, renders, and sprite sheets
Aseprite or LibreSprite → cleans pixels, palettes, outlines, and animations
Roblox Studio → imports and tests the final assets
```

## Best use cases

Blender is a good fit for:

- Isometric sprites.
- 3D props rendered as 2D sprites.
- Multiple angles of the same object.
- Consistent character or item variations.
- Sprite sheets generated from repeatable scenes.
- Low-poly Roblox props and environments.
- Batch renders and exports.

Use a pixel-art editor after Blender when the result needs deliberate pixel placement, palette control, cleanup, or animation polish.

## Pixel-sprite settings

Start with:

```text
Camera: Orthographic
Resolution: 32x32, 64x64, or 128x128
Render: Eevee or the current real-time Blender renderer
Output: PNG with transparent background
Materials: limited palette
Lighting: simple and consistent
Texture filtering: nearest/point when scaling pixel textures
```

For a first test, create one sword or prop, render four directions at 64x64, and export the images to a `sprites/` folder. Only build a full pipeline after the first result looks useful.

## Quality workflow

```text
1. Define target: Roblox, game style, sprite size, palette, and camera.
2. Create a simple blockout.
3. Render a preview.
4. Check silhouette at the final sprite size.
5. Improve proportions and readability.
6. Add materials and controlled lighting.
7. Pixel-clean in Aseprite or LibreSprite.
8. Export PNGs or a sprite sheet.
9. Import into Roblox and test at real in-game scale.
```

## Prompt template

```text
Create a stylized low-poly [object/character] for a Roblox game.

Target:
- Final sprite size: 64x64
- Camera: orthographic, three-quarter view
- Style: readable, chunky, colorful, game-ready
- Palette: limited and consistent
- Background: transparent
- Materials: simple
- Separate parts that may need animation
- Output: Blender file and PNG preview

First create a blockout and render a preview. Do not add detail until the
silhouette is readable at 64x64. Keep the original file safe and save outputs
in a new folder.
```

## Safety

- Save a copy before an AI edits a Blender file.
- Use one Blender MCP server at a time.
- Do not run unknown scripts in a valuable scene without inspecting them.
- Keep API keys outside this repository.
- Check the license of every downloaded asset before commercial use.
