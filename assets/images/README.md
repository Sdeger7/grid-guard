# Image assets (placeholder stage)

There are **no PNG sprites here yet, by design.** Phase 1–3 render every tower,
enemy, tile, and structure as a procedurally drawn shaded isometric shape.

When production art is ready, drop sprite sheets / atlases here and point the
catalogs (`lib/data/tower_catalog.dart`, `lib/data/enemy_catalog.dart`) at the
new sprite references. The rendering layer already reads its visual per
tower/enemy type from those catalogs, so no gameplay logic changes are needed.
