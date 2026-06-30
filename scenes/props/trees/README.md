# Árboles del pack `tree_1.glb`

## Por qué fallan borrar / Save Branch as Scene

Si instancias `tree_1.glb` dentro de `trees.tscn`, los nodos `Tree_4`, `Tree_3`, etc. **pertenecen al GLB**, no a tu escena. Godot muestra:

- *"Can't operate on nodes from a foreign scene!"* — al borrar sin hacer local la instancia.
- *"Node must belong to the edited scene to become root."* — al usar **Save Branch as Scene** sobre un hijo del GLB desde otra escena.

Eso es comportamiento normal, no un bug.

---

## Opción A — Prop reutilizable (recomendada para la demo)

Usa `scenes/props/trees/tree_pack_prop.tscn`:

1. Instancia esa escena en `level_2` (o donde quieras).
2. En el inspector, propiedad **Tree Variant** elige el nombre del mesh:
   - `Tree_4`
   - `Tree_3`
   - `Tree_1`
   - `Tree_2`
   - `Tree_5`
   - `Tree_6`
   - `Tree_7`
   - `Tree`
3. Duplica la instancia y cambia **Tree Variant** para otro árbol.
4. Rota/traslada el nodo raíz `TreePackProp` para pruebas (p. ej. árbol caído).

### Colisiones

Las formas de colisión viven en `scenes/objects/trees.tscn` (StaticBody3D bajo cada `Tree_*`).
`tree_pack_prop` **instancia esa escena**, no el GLB a pelo, y activa solo la colisión del árbol visible.

**Si ajustas colisiones:** edítalas en `trees.tscn` (sobre el GLB con *Editable Children*).
Los cambios se aplican a todas las instancias de `tree_pack_prop` automáticamente.

El script es `@tool`: en el **viewport del editor** solo se ve el árbol elegido, igual que en runtime.

---

## Opción B — Escena propia por árbol (Save Branch, forma correcta)

Para un `.tscn` dedicado (`tree_4.tscn`, `tree_3.tscn`, …) **sin** cargar el pack entero en runtime:

1. En **FileSystem**, doble clic en `res://assets/models/objects/trees/tree_1.glb`.  
   Se abre el GLB como escena propia (pestaña nueva).
2. En **esa** pestaña (no en `trees.tscn`), clic derecho en `Tree_4` → **Save Branch as Scene…**
3. Guarda como `scenes/props/trees/tree_4.tscn`.
4. Repite para otros árboles si los necesitas.
5. En `level_2`, instancia `tree_4.tscn` (no el GLB completo ni `trees.tscn`).

Aquí **Save Branch** sí funciona porque estás editando la escena del GLB, no una instancia foránea.

### Si quieres borrar hermanos en lugar de Save Branch

1. Abre `tree_1.glb` directamente (doble clic).
2. Borra todos los nodos excepto `Tree_4`.
3. **Scene → Save Scene As…** → `tree_4.tscn`.

---

## Opción C — Catálogo `trees.tscn`

`scenes/objects/trees.tscn` puede quedarse como **vitrina** para comparar modelos en el editor. **No** la instancies en niveles jugables.

---

## Resumen

| Objetivo | Qué usar |
|----------|----------|
| Rápido, varios árboles en level_2 | `tree_pack_prop.tscn` + **Tree Variant** |
| Máximo rendimiento / prop limpio | Save Branch desde **GLB abierto** → `tree_4.tscn` |
| Ver todos los modelos | `trees.tscn` (solo editor) |
